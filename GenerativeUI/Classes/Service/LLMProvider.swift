import Foundation

/// A single message in an LLM conversation.
///
/// This is the framework's own message type, independent of any LLM SDK.
/// Concrete ``LLMProvider`` implementations map these to their SDK's format.
public struct LLMMessage: Sendable {

    /// The role of the message sender.
    public enum Role: String, Sendable {
        case system
        case user
        case assistant
    }

    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

/// Abstraction over any LLM backend (DeepSeek, OpenAI, Claude, etc.).
///
/// The framework calls ``sendMessages(_:)`` and expects a plain-text response.
/// The concrete implementation lives in the host app — the framework never
/// imports a specific LLM SDK.
///
/// ## Conformance Example
/// ```swift
/// final class MyProvider: LLMProvider {
///     func sendMessages(_ messages: [LLMMessage]) async throws -> String {
///         // call your LLM API here
///     }
/// }
/// ```
public protocol LLMProvider: Sendable {
    /// Sends a conversation and returns the assistant's raw text response.
    func sendMessages(_ messages: [LLMMessage]) async throws -> String
}
