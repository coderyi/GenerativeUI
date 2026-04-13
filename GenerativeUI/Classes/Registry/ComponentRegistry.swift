import Foundation

/// The central registry for component and action definitions.
/// All component types and actions must be registered here before use.
public final class ComponentRegistry {

    private var components: [String: ComponentDefinition] = [:]
    private var actions: [String: ActionDefinition] = [:]

    public init() {}

    // MARK: - Component Registration

    /// Registers a component definition.
    public func register(component: ComponentDefinition) {
        components[component.type.rawValue] = component
    }

    /// Returns the definition for the given component type string, or nil if not registered.
    public func componentDefinition(for type: String) -> ComponentDefinition? {
        components[type]
    }

    /// Returns true if the given component type string is registered.
    public func isComponentRegistered(_ type: String) -> Bool {
        components[type] != nil
    }

    /// Returns all registered component type strings.
    public var registeredComponentTypes: [String] {
        Array(components.keys)
    }

    // MARK: - Action Registration

    /// Registers an action definition.
    public func register(action: ActionDefinition) {
        actions[action.id] = action
    }

    /// Returns the definition for the given action ID, or nil if not registered.
    public func actionDefinition(for id: String) -> ActionDefinition? {
        actions[id]
    }

    /// Returns true if the given action ID is registered.
    public func isActionRegistered(_ id: String) -> Bool {
        actions[id] != nil
    }

    /// Returns all registered action IDs.
    public var registeredActionIds: [String] {
        Array(actions.keys)
    }
}

// MARK: - Default Registry

extension ComponentRegistry {

    /// Creates a registry pre-populated with all MVP component definitions and common actions.
    public static func makeDefault() -> ComponentRegistry {
        let registry = ComponentRegistry()

        // Register all component definitions
        registry.register(component: TextComponentDefinition())
        registry.register(component: SectionComponentDefinition())
        registry.register(component: TextInputComponentDefinition())
        registry.register(component: ButtonComponentDefinition())
        registry.register(component: SingleSelectComponentDefinition())
        registry.register(component: RowComponentDefinition())
        registry.register(component: ColumnComponentDefinition())

        registry.register(component: ImageComponentDefinition())
        registry.register(component: ListComponentDefinition())
        registry.register(component: TabsComponentDefinition())
        registry.register(component: ModalComponentDefinition())
        registry.register(component: DateTimeInputComponentDefinition())
        registry.register(component: CheckboxComponentDefinition())

        return registry
    }
}
