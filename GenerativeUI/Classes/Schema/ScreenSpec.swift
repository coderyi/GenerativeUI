import Foundation

/// A single screen specification containing an ID, title, initial state, and a list of components.
public struct ScreenSpec: Decodable, Equatable {
    /// Unique screen identifier.
    public let id: String
    /// Display title for the screen.
    public let title: String
    /// Initial state values. Keys are field names; values are initial field values.
    public let state: [String: JSONValue]
    /// Ordered list of top-level components.
    public let components: [ComponentSpec]

    public init(id: String, title: String, state: [String: JSONValue], components: [ComponentSpec]) {
        self.id = id
        self.title = title
        self.state = state
        self.components = components
    }
}

/// A single component node in the UI tree.
public struct ComponentSpec: Decodable, Equatable {
    /// Unique component identifier within the screen.
    public let id: String
    /// The component type as a raw string (e.g. "text", "button", "section").
    public let type: String
    /// Component-specific properties. Validated against the registry.
    public let props: [String: JSONValue]
    /// Optional action to trigger on interaction.
    public let action: ActionSpec?
    /// Child components (only valid for container types like "section", "row", "column").
    public let children: [ComponentSpec]?

    public init(
        id: String,
        type: String,
        props: [String: JSONValue],
        action: ActionSpec? = nil,
        children: [ComponentSpec]? = nil
    ) {
        self.id = id
        self.type = type
        self.props = props
        self.action = action
        self.children = children
    }
}

/// An action that can be triggered by interactive components.
public struct ActionSpec: Decodable, Equatable {
    /// The action identifier, e.g. "booking.submit".
    public let id: String

    public init(id: String) {
        self.id = id
    }
}

/// Supported component types.
public enum ComponentType: String, CaseIterable {
    case text
    case section
    case textInput
    case button
    case singleSelect
    case row
    case column
    case image
    case list
    case modal
    case tabs
    case dateTimeInput
    case checkbox
}
