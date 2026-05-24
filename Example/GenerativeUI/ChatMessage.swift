import UIKit
import GenerativeUI

/// Represents a single message in the chat flow.
struct ChatMessage {
    let id: UUID
    let role: Role
    let content: Content
    let timestamp: Date

    enum Role {
        case user
        case assistant
    }

    enum Content {
        /// Plain text (user input, error messages, etc.)
        case text(String)
        /// A rendered ViewSpec card with interactive capabilities.
        case viewSpec(GenerativeViewRenderer)
        /// A loading placeholder while waiting for LLM response.
        case loading
    }

    // MARK: - Convenience Initializers

    static func user(_ text: String) -> ChatMessage {
        ChatMessage(id: UUID(), role: .user, content: .text(text), timestamp: Date())
    }

    static func assistantText(_ text: String) -> ChatMessage {
        ChatMessage(id: UUID(), role: .assistant, content: .text(text), timestamp: Date())
    }

    static func assistantView(_ renderer: GenerativeViewRenderer) -> ChatMessage {
        ChatMessage(id: UUID(), role: .assistant, content: .viewSpec(renderer), timestamp: Date())
    }

    static func loading() -> ChatMessage {
        ChatMessage(id: UUID(), role: .assistant, content: .loading, timestamp: Date())
    }
}
