import Foundation

/// Bridges user interactions from rendered components into standardized `InteractionEnvelope` events.
/// The host app provides the `onEvent` handler to receive and process these events.
public final class EventBridge {

    /// The component registry, used by container components to resolve child definitions.
    public let registry: ComponentRegistry

    /// The event handler provided by the host app.
    public var onEvent: ((InteractionEnvelope) -> Void)?

    private let logger = GenerativeUILogger.shared

    public init(registry: ComponentRegistry) {
        self.registry = registry
    }

    /// Sends a `valueChanged` event for a bound field update.
    public func sendValueChanged(
        specId: String,
        componentId: String,
        binding: String,
        value: JSONValue,
        state: [String: JSONValue]
    ) {
        let envelope = InteractionEnvelope(
            eventType: .valueChanged,
            specId: specId,
            componentId: componentId,
            binding: binding,
            value: value,
            state: state
        )
        dispatch(envelope)
    }

    /// Sends an `actionTriggered` event for a button or action component.
    public func sendActionTriggered(
        specId: String,
        componentId: String,
        actionId: String?,
        state: [String: JSONValue]
    ) {
        let envelope = InteractionEnvelope(
            eventType: .actionTriggered,
            specId: specId,
            componentId: componentId,
            actionId: actionId,
            state: state
        )
        dispatch(envelope)
    }

    private func dispatch(_ envelope: InteractionEnvelope) {
        logger.info(
            "Event dispatched",
            fields: [
                "event_type": envelope.eventType.rawValue,
                "spec_id": envelope.specId,
                "component_id": envelope.componentId,
                "action_id": envelope.actionId ?? "-",
                "binding": envelope.binding ?? "-"
            ]
        )
        onEvent?(envelope)
    }
}
