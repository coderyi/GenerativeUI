import UIKit

/// Definition for the `list` component type.
/// A vertical container that arranges children with optional dividers between items.
///
/// Compared to `column`, `list` adds visual separation semantics (dividers)
/// and is intended for item-level content rather than generic layout.
internal final class ListComponentDefinition: ComponentDefinition {
    let type: ComponentType = .list
    let category: ComponentCategory = .layout
    let allowsChildren = true
    let supportedEvents: Set<EventType> = []
    let requiredProps: Set<String> = []

    func validate(props: [String: JSONValue]) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if let spacing = props["spacing"], spacing.doubleValue ?? -1 < 0 {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.spacing",
                message: "list spacing must be >= 0"
            ))
        }
        return issues
    }

    func makeView(component: ComponentSpec, context: RenderContext) -> UIView {
        let spacing = component.props["spacing"]?.doubleValue ?? 8
        let showDivider = component.props["showDivider"]?.boolValue ?? false

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = spacing
        stack.alignment = .fill

        guard let children = component.children else { return stack }

        for (index, child) in children.enumerated() {
            guard let definition = context.eventBridge.registry.componentDefinition(for: child.type) else {
                GenerativeUILogger.shared.warning(
                    "Skipping unregistered component type in list",
                    fields: ["component_id": child.id, "type": child.type]
                )
                continue
            }

            let childView = definition.makeView(component: child, context: context)
            stack.addArrangedSubview(childView)

            // Insert divider between items (not after the last one)
            if showDivider && index < children.count - 1 {
                let divider = Self.makeDivider()
                stack.addArrangedSubview(divider)
            }
        }

        return stack
    }

    // MARK: - Helpers

    private static func makeDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale).isActive = true
        return divider
    }

}
