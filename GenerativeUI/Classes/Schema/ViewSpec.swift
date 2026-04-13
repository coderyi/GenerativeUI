import Foundation

/// A view (block-level) specification containing an ID, optional initial state, and a list of components.
/// Unlike `ScreenSpec`, a view has no title and no navigation semantics — it is designed to be
/// embedded into an existing page, presented as a sheet, or used in any context the host decides.
public struct ViewSpec: Decodable, Equatable {
    /// Unique view identifier.
    public let id: String
    /// Initial state values. Nil for display-only views that require no state.
    public let state: [String: JSONValue]?
    /// Ordered list of top-level components. Shares the same `ComponentSpec` model as `ScreenSpec`.
    public let components: [ComponentSpec]

    public init(id: String, state: [String: JSONValue]? = nil, components: [ComponentSpec]) {
        self.id = id
        self.state = state
        self.components = components
    }
}
