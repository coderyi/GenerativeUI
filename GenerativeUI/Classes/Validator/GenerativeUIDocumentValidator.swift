import Foundation

/// Validates GenerativeUI documents against schema version, structure, and semantic rules.
/// Accumulates all issues and returns them together for comprehensive error reporting.
public final class GenerativeUIDocumentValidator {

    /// The set of schema versions supported by this validator.
    public static let supportedVersions: Set<String> = ["0.1"]

    private let registry: ComponentRegistry

    public init(registry: ComponentRegistry) {
        self.registry = registry
    }

    // MARK: - Unified Document Validation

    /// Validates a `GenerativeUIDocument`. Returns an empty array if valid.
    public func validate(_ document: GenerativeUIDocument) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        // 1. Version check
        if !Self.supportedVersions.contains(document.schemaVersion) {
            issues.append(ValidationIssue(
                code: .unsupportedSchemaVersion,
                path: "schemaVersion",
                message: "Unsupported schema version '\(document.schemaVersion)'. Supported: \(Self.supportedVersions.sorted().joined(separator: ", "))"
            ))
            return issues
        }

        // 2. Content-specific validation
        switch document.content {
        case .screen(let screen):
            validateScreen(screen, issues: &issues)
        case .view(let view):
            validateView(view, issues: &issues)
        }

        return issues
    }

    // MARK: - Screen Validation

    private func validateScreen(_ screen: ScreenSpec, issues: inout [ValidationIssue]) {
        if screen.id.isEmpty {
            issues.append(ValidationIssue(
                code: .missingRequiredField,
                path: "screen.id",
                message: "screen.id must not be empty"
            ))
        }
        if screen.title.isEmpty {
            issues.append(ValidationIssue(
                code: .missingRequiredField,
                path: "screen.title",
                message: "screen.title must not be empty"
            ))
        }

        var seenIds: Set<String> = []
        validateComponents(
            screen.components,
            pathPrefix: "screen",
            stateKeys: Set(screen.state.keys),
            seenIds: &seenIds,
            issues: &issues
        )
    }

    // MARK: - View Validation

    private func validateView(_ view: ViewSpec, issues: inout [ValidationIssue]) {
        if view.id.isEmpty {
            issues.append(ValidationIssue(
                code: .missingRequiredField,
                path: "view.id",
                message: "view.id must not be empty"
            ))
        }
        if view.components.isEmpty {
            issues.append(ValidationIssue(
                code: .missingRequiredField,
                path: "view.components",
                message: "view.components must contain at least one component"
            ))
        }

        let stateKeys: Set<String> = view.state.map { Set($0.keys) } ?? []
        var seenIds: Set<String> = []
        validateComponents(
            view.components,
            pathPrefix: "view",
            stateKeys: stateKeys,
            seenIds: &seenIds,
            issues: &issues
        )
    }

    // MARK: - Shared Component Tree Validation

    private func validateComponents(
        _ components: [ComponentSpec],
        pathPrefix: String,
        stateKeys: Set<String>,
        seenIds: inout Set<String>,
        issues: inout [ValidationIssue]
    ) {
        for (index, component) in components.enumerated() {
            validateComponent(
                component,
                path: "\(pathPrefix).components[\(index)]",
                stateKeys: stateKeys,
                seenIds: &seenIds,
                issues: &issues,
                depth: 0
            )
        }
    }

    private func validateComponent(
        _ component: ComponentSpec,
        path: String,
        stateKeys: Set<String>,
        seenIds: inout Set<String>,
        issues: inout [ValidationIssue],
        depth: Int
    ) {
        // Duplicate ID check
        if seenIds.contains(component.id) {
            issues.append(ValidationIssue(
                code: .duplicateComponentID,
                path: "\(path).id",
                message: "Duplicate component ID '\(component.id)'"
            ))
        }
        seenIds.insert(component.id)

        // Component type registration check
        guard let definition = registry.componentDefinition(for: component.type) else {
            issues.append(ValidationIssue(
                code: .unsupportedComponentType,
                path: "\(path).type",
                message: "Unknown component type '\(component.type)'"
            ))
            return
        }

        // Children constraint check
        let hasChildren = component.children != nil && !(component.children?.isEmpty ?? true)
        if hasChildren && !definition.allowsChildren {
            issues.append(ValidationIssue(
                code: .invalidChildrenUsage,
                path: "\(path).children",
                message: "Component type '\(component.type)' does not allow children"
            ))
        }

        // Props validation via component definition
        let propIssues = definition.validate(props: component.props)
        for issue in propIssues {
            issues.append(ValidationIssue(
                code: issue.code,
                path: "\(path).\(issue.path)",
                message: issue.message
            ))
        }

        // Binding validation: binding must reference a declared state key
        if let binding = component.props["binding"]?.stringValue {
            if !stateKeys.contains(binding) {
                issues.append(ValidationIssue(
                    code: .invalidBinding,
                    path: "\(path).props.binding",
                    message: "Binding '\(binding)' does not reference a declared state field"
                ))
            }
        }

        // Action validation
        if let action = component.action {
            if let actionDef = registry.actionDefinition(for: action.id) {
                if let componentType = ComponentType(rawValue: component.type),
                   !actionDef.allowedComponentTypes.contains(componentType) {
                    issues.append(ValidationIssue(
                        code: .invalidAction,
                        path: "\(path).action.id",
                        message: "Action '\(action.id)' is not allowed for component type '\(component.type)'"
                    ))
                }
            }
            // Note: unregistered actions are allowed in MVP (host can define them dynamically)
        }

        // Recurse into children
        if let children = component.children {
            for (index, child) in children.enumerated() {
                validateComponent(
                    child,
                    path: "\(path).children[\(index)]",
                    stateKeys: stateKeys,
                    seenIds: &seenIds,
                    issues: &issues,
                    depth: depth + 1
                )
            }
        }
    }
}
