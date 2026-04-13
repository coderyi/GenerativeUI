import Foundation

/// Controls automatic retry behavior when LLM-generated JSON fails
/// decoding or validation.
///
/// When a ``GenerativeUILLMService`` pipeline fails, the retry policy
/// determines whether to re-invoke the LLM with error feedback appended
/// to the conversation, giving the model a chance to self-correct.
public struct RetryPolicy: Sendable {

    /// Maximum number of retry attempts (0 means no retries).
    public let maxRetries: Int

    /// Builds a feedback message from a ``GenerativeUIError`` to send back
    /// to the LLM so it can correct its output.
    public let feedbackBuilder: @Sendable (GenerativeUIError) -> String

    /// Default policy: 1 retry with a built-in feedback message.
    public static let `default` = RetryPolicy(maxRetries: 1)

    /// No retries — fail immediately.
    public static let none = RetryPolicy(maxRetries: 0)

    /// Creates a retry policy.
    ///
    /// - Parameters:
    ///   - maxRetries: Maximum retry attempts (default 1).
    ///   - feedbackBuilder: Converts an error into a feedback prompt for the LLM.
    ///     If `nil`, a sensible default builder is used.
    public init(
        maxRetries: Int = 1,
        feedbackBuilder: (@Sendable (GenerativeUIError) -> String)? = nil
    ) {
        self.maxRetries = max(maxRetries, 0)
        self.feedbackBuilder = feedbackBuilder ?? Self.defaultFeedback
    }

    // MARK: - Default Feedback

    private static let defaultFeedback: @Sendable (GenerativeUIError) -> String = { error in
        let detail: String
        switch error {
        case .extractionFailed(let desc):
            detail = "No valid JSON found in your response. \(desc.message)"
        case .decodingFailed(let desc):
            detail = "JSON decoding failed: \(desc.message)"
        case .validationFailed(let issues):
            let issueLines = issues.prefix(5).map { "- [\($0.path)] \($0.message)" }
            detail = "Validation errors:\n\(issueLines.joined(separator: "\n"))"
        case .generationFailed(let desc):
            detail = "Generation failed: \(desc.message)"
        case .renderingFailed(let desc):
            detail = "Rendering failed: \(desc.message)"
        }

        return """
        Your previous JSON output is invalid. \(detail)

        Please regenerate a valid JSON response following the schema rules exactly.
        Output only the JSON, no other text.
        """
    }
}
