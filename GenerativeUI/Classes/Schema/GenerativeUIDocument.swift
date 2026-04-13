import Foundation

/// The unified top-level document for the GenerativeUI framework.
/// Wraps a schema version and exactly one content payload: either a screen or a view.
///
/// - `screen`: A full-page specification with title, state, and navigation semantics.
/// - `view`: A block-level specification designed for embedding, sheets, or other host-decided presentation.
///
/// Current supported schema version: `"0.1"`.
public struct GenerativeUIDocument: Equatable {
    /// The schema version string, currently `"0.1"`.
    public let schemaVersion: String
    /// The document content — either a screen or a view.
    public let content: GenerativeUIContent

    public init(schemaVersion: String, content: GenerativeUIContent) {
        self.schemaVersion = schemaVersion
        self.content = content
    }
}

/// The document content: a full-page screen or an embeddable view.
/// Modeled as an enum so invalid states (both present, neither present) are impossible at compile time.
public enum GenerativeUIContent: Equatable {
    case screen(ScreenSpec)
    case view(ViewSpec)
}

// MARK: - Decodable

extension GenerativeUIDocument: Decodable {

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case screen
        case view
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decode(String.self, forKey: .schemaVersion)

        let hasScreen = container.contains(.screen)
        let hasView = container.contains(.view)

        switch (hasScreen, hasView) {
        case (true, false):
            let screen = try container.decode(ScreenSpec.self, forKey: .screen)
            self.content = .screen(screen)
        case (false, true):
            let view = try container.decode(ViewSpec.self, forKey: .view)
            self.content = .view(view)
        case (true, true):
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Document must contain either 'screen' or 'view', not both"
                )
            )
        case (false, false):
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Document must contain either 'screen' or 'view'"
                )
            )
        }
    }
}
