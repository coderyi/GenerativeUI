import UIKit

/// The functional category of a component.
/// Used on the development side only (registration, validation, catalog generation).
/// This does NOT appear in the JSON schema.
public enum ComponentCategory: String {
    /// Container that manages child layout (Section, Row, Column).
    case layout
    /// Pure display, no events or bindings (Text).
    case display
    /// Has events or state bindings (Button, TextInput, SingleSelect).
    case interactive
}

/// Defines the protocol and rendering capabilities for a registered component type.
public protocol ComponentDefinition {
    /// The component type this definition handles.
    var type: ComponentType { get }
    /// The functional category of this component (layout / display / interactive).
    var category: ComponentCategory { get }
    /// Whether this component type can contain children.
    var allowsChildren: Bool { get }
    /// The event types this component can produce.
    var supportedEvents: Set<EventType> { get }
    /// Required property keys for this component type.
    var requiredProps: Set<String> { get }

    /// Validates the props dictionary for this component type.
    /// Returns an empty array if all props are valid.
    func validate(props: [String: JSONValue]) -> [ValidationIssue]

    /// Creates a UIView for the given component spec and render context.
    func makeView(component: ComponentSpec, context: RenderContext) -> UIView
}

/// Context passed to component definitions during rendering.
/// Provides access to state, event dispatch, and the spec identity (screen or view).
public final class RenderContext {
    public let specId: String
    public let stateStore: StateStore
    public let eventBridge: EventBridge

    public init(specId: String, stateStore: StateStore, eventBridge: EventBridge) {
        self.specId = specId
        self.stateStore = stateStore
        self.eventBridge = eventBridge
    }
}
