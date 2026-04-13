import Foundation

/// Event types supported in the MVP.
public enum EventType: String, Encodable {
    /// A bound value was changed (e.g. text input, single select).
    case valueChanged
    /// An action was triggered (e.g. button tap).
    case actionTriggered
}

/// A standardized event payload sent from the UI runtime to the host app.
/// Contains all information the host needs to decide on the next action.
public struct InteractionEnvelope: Encodable, Equatable {
    /// The type of event.
    public let eventType: EventType
    /// The spec (screen or view) that originated this event.
    public let specId: String
    /// The component that triggered this event.
    public let componentId: String
    /// The action ID, present only for `actionTriggered` events.
    public let actionId: String?
    /// The state binding key, present only for `valueChanged` events.
    public let binding: String?
    /// The current value, present only for `valueChanged` events.
    public let value: JSONValue?
    /// A snapshot of all current state values at the time of the event.
    public let state: [String: JSONValue]

    public init(
        eventType: EventType,
        specId: String,
        componentId: String,
        actionId: String? = nil,
        binding: String? = nil,
        value: JSONValue? = nil,
        state: [String: JSONValue]
    ) {
        self.eventType = eventType
        self.specId = specId
        self.componentId = componentId
        self.actionId = actionId
        self.binding = binding
        self.value = value
        self.state = state
    }
}
