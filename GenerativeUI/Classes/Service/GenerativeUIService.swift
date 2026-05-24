import Foundation

/// Protocol for services that generate UI from a user message.
///
/// Both mock (local JSON) and LLM-powered implementations conform to this
/// protocol, returning a unified ``GenerativeUIDocument`` that supports
/// schema 0.1 (both screen and view content).
///
/// ## Conforming Types
/// - ``GenerativeUILLMService`` — calls an LLM via ``LLMProvider``
/// - Host-provided mock services that load local JSON for development
public protocol GenerativeUIService {
    /// Generates a UI document from a user's natural language description.
    ///
    /// - Parameter message: The user's description of the desired UI.
    /// - Returns: A decoded ``GenerativeUIDocument``.
    /// - Throws: ``GenerativeUIError`` on failure.
    func generate(message: String) async throws -> GenerativeUIDocument
}
