import Foundation

/// Orchestrates the full LLM-to-document pipeline:
/// **user message → LLM → extract JSON → fix → decode → validate → (retry) → document**.
///
/// This is the primary integration point for LLM-powered UI generation.
/// The host app provides a concrete ``LLMProvider`` (e.g. wrapping DeepSeek,
/// OpenAI, Claude) and receives back a decoded ``GenerativeUIDocument``
/// ready for rendering.
///
/// ## Usage
/// ```swift
/// let provider = MyLLMProvider(apiKey: "…")
/// let service = GenerativeUILLMService(provider: provider)
/// let document = try await service.generate(message: "生成一个酒店卡片")
/// let result = runtime.build(from: document) { envelope in … }
/// ```
// @unchecked Sendable: all stored properties are `let` and either Sendable
// value types or Sendable protocol types. The `logger` is a shared singleton
// (`GenerativeUILogger.shared`) whose publicly-exposed API is read-only from
// callers, and the `validator` is immutable after init.
public final class GenerativeUILLMService: GenerativeUIService, @unchecked Sendable {

    /// The LLM backend.
    public let provider: LLMProvider

    /// JSON extractor for pulling JSON from raw LLM text.
    public let extractor: JSONExtractor

    /// JSON fixer for repairing common LLM output errors.
    public let fixer: JSONFixer

    /// Retry policy for automatic re-generation on failure.
    public let retryPolicy: RetryPolicy

    /// The system prompt sent to the LLM.
    public let systemPrompt: String

    /// The validator used for checking generated documents.
    private let validator: GenerativeUIDocumentValidator

    private let logger = GenerativeUILogger.shared

    /// Creates a new LLM service.
    ///
    /// - Parameters:
    ///   - provider:     A concrete ``LLMProvider`` implementation.
    ///   - systemPrompt: The system prompt sent to the LLM (required — the
    ///                   framework does not ship a default prompt).
    ///   - extractor:    Custom JSON extractor. Defaults to ``JSONExtractor/default``.
    ///   - fixer:        Custom JSON fixer. Defaults to ``JSONFixer/default``.
    ///   - retryPolicy:  Retry behavior on failure. Defaults to ``RetryPolicy/default`` (1 retry).
    ///   - registry:     Component registry for validation. Defaults to ``ComponentRegistry/makeDefault()``.
    public init(
        provider: LLMProvider,
        systemPrompt: String,
        extractor: JSONExtractor = .default,
        fixer: JSONFixer = .default,
        retryPolicy: RetryPolicy = .default,
        registry: ComponentRegistry = .makeDefault()
    ) {
        self.provider = provider
        self.systemPrompt = systemPrompt
        self.extractor = extractor
        self.fixer = fixer
        self.retryPolicy = retryPolicy
        self.validator = GenerativeUIDocumentValidator(registry: registry)
    }

    // MARK: - GenerativeUIService

    /// Generates a UI document from a user message.
    public func generate(message: String) async throws -> GenerativeUIDocument {
        try await generate(message: message, context: [])
    }

    // MARK: - Extended API

    /// Full pipeline: user message → LLM → extract → fix → decode → validate.
    ///
    /// On decode/validation failure and if retries remain, the error is fed
    /// back to the LLM as a user message so it can self-correct.
    ///
    /// - Parameters:
    ///   - message: The user's natural language description.
    ///   - context: Additional conversation history to prepend.
    /// - Returns: A decoded and validated ``GenerativeUIDocument``.
    /// - Throws: ``GenerativeUIError`` if all attempts fail.
    public func generate(
        message: String,
        context: [LLMMessage]
    ) async throws -> GenerativeUIDocument {
        // Build initial message array
        var messages: [LLMMessage] = [
            LLMMessage(role: .system, content: systemPrompt)
        ]
        messages.append(contentsOf: context)
        messages.append(LLMMessage(role: .user, content: message))

        // Attempt generation with retries
        var lastError: GenerativeUIError?

        for attempt in 0...(retryPolicy.maxRetries) {
            // On retry, append the failed response context and error feedback
            if attempt > 0, let error = lastError {
                let feedback = retryPolicy.feedbackBuilder(error)
                messages.append(LLMMessage(role: .user, content: feedback))
                logger.info("Retrying LLM generation", fields: [
                    "attempt": "\(attempt + 1)",
                    "reason": "\(error)"
                ])
            }

            do {
                let document = try await attemptGenerate(messages: messages)
                return document
            } catch let error as GenerativeUIError {
                lastError = error
                continue
            } catch {
                // Unexpected error — don't retry
                throw GenerativeUIError.generationFailed(
                    ErrorDescriptor(code: "LLM_ERROR", message: error.localizedDescription)
                )
            }
        }

        // All attempts exhausted
        throw lastError ?? GenerativeUIError.generationFailed(
            ErrorDescriptor(code: "UNKNOWN", message: "Generation failed after all retry attempts")
        )
    }

    /// Lower-level: sends messages and returns the extracted + fixed JSON string.
    ///
    /// Useful when the caller wants to handle decoding/validation themselves.
    ///
    /// - Parameter messages: The full conversation to send.
    /// - Returns: Extracted and repaired JSON string.
    /// - Throws: ``GenerativeUIError/generationFailed(_:)`` or
    ///           ``GenerativeUIError/extractionFailed(_:)``.
    public func sendAndExtract(messages: [LLMMessage]) async throws -> String {
        // 1. Call LLM
        let rawResponse: String
        do {
            rawResponse = try await provider.sendMessages(messages)
        } catch {
            throw GenerativeUIError.generationFailed(
                ErrorDescriptor(code: "LLM_ERROR", message: error.localizedDescription)
            )
        }

        logger.debug("LLM raw response", fields: [
            "length": "\(rawResponse.count)"
        ])

        // 2. Extract JSON
        let extracted = extractor.extract(from: rawResponse)

        // If extraction returned the original text unchanged and it doesn't
        // look like JSON, report an extraction failure so retry can kick in.
        let trimmed = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.hasPrefix("{") && !trimmed.hasPrefix("[") {
            throw GenerativeUIError.extractionFailed(
                ErrorDescriptor(
                    code: "NO_JSON",
                    message: "LLM response does not contain recognizable JSON"
                )
            )
        }

        // 3. Fix common errors
        let fixed = fixer.fix(extracted)

        return fixed
    }

    // MARK: - Private

    /// Single attempt: send → extract → fix → decode → validate.
    private func attemptGenerate(messages: [LLMMessage]) async throws -> GenerativeUIDocument {
        let jsonString = try await sendAndExtract(messages: messages)

        // 4. Decode
        let document: GenerativeUIDocument
        do {
            document = try SchemaDecoder.decodeDocument(from: jsonString)
        } catch let error as GenerativeUIError {
            throw error
        } catch {
            throw GenerativeUIError.decodingFailed(
                ErrorDescriptor(code: "DECODE_ERROR", message: error.localizedDescription)
            )
        }

        // 5. Validate
        let issues = validator.validate(document)
        if !issues.isEmpty {
            throw GenerativeUIError.validationFailed(issues)
        }

        return document
    }
}
