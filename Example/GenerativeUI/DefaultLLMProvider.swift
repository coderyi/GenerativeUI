import Foundation
import GenerativeUI
import AgentSwift

/// The default ``LLMProvider`` implementation for the Example app.
///
/// Wraps AgentSwift's `Agent` to call an LLM backend. The concrete model
/// is configurable via the `model` parameter.
///
/// This adapter lives in the Example app — the framework never imports
/// AgentSwift directly.
///
/// ## Conversation Management
///
/// AgentSwift's `Agent.run()` accepts a single input string and manages
/// conversation history internally. This provider maps the stateless
/// ``LLMProvider/sendMessages(_:)`` contract onto AgentSwift by:
/// 1. Creating a fresh `Agent` per call to avoid stale state.
/// 2. Passing the system message via `Agent(system:)`.
/// 3. Concatenating all user messages into a single input string,
///    so retry feedback from ``RetryPolicy`` is included.
final class DefaultLLMProvider: LLMProvider {

    private let apiKey: String
    private let modelName: String

    /// Creates a provider.
    ///
    /// - Parameters:
    ///   - apiKey: API key for the LLM backend.
    ///   - model:  Model identifier (default: `"deepseek-chat"`).
    init(apiKey: String, model: String = "deepseek-chat") {
        self.apiKey = apiKey
        self.modelName = model
    }

    func sendMessages(_ messages: [LLMMessage]) async throws -> String {
        // The system prompt is the first message (role == .system).
        let systemMessage = messages.first(where: { $0.role == .system })?.content
        let agent = Agent(
            model: .deepSeek(apiKey: apiKey, model: modelName),
            tools: [],
            system: systemMessage
        )

        // AgentSwift's Agent.run() accepts a single input string.
        // Concatenate all user messages so retry feedback is included.
        let userParts = messages
            .filter { $0.role == .user }
            .map { $0.content }

        guard !userParts.isEmpty else {
            throw GenerativeUIError.generationFailed(
                ErrorDescriptor(code: "NO_USER_MESSAGE", message: "No user message found in conversation")
            )
        }

        let combinedInput = userParts.joined(separator: "\n\n")
        let result = try await agent.run(combinedInput)
        return result.text
    }
}
