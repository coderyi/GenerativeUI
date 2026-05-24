import Foundation

/// Defines a registered action and which component types are allowed to trigger it.
public struct ActionDefinition {
    /// The action identifier, e.g. "booking.submit".
    public let id: String
    /// The set of component types allowed to trigger this action.
    public let allowedComponentTypes: Set<ComponentType>

    public init(id: String, allowedComponentTypes: Set<ComponentType>) {
        self.id = id
        self.allowedComponentTypes = allowedComponentTypes
    }
}
