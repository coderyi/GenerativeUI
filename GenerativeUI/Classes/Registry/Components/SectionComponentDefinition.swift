import UIKit

/// Definition for the `section` component type.
/// A container that groups child components with an optional title header.
internal final class SectionComponentDefinition: ComponentDefinition {
    let type: ComponentType = .section
    let category: ComponentCategory = .layout
    let allowsChildren = true
    let supportedEvents: Set<EventType> = []
    let requiredProps: Set<String> = []

    func validate(props: [String: JSONValue]) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if let title = props["title"], title.stringValue == nil {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.title",
                message: "section title must be a string if provided"
            ))
        }
        if let spacing = props["spacing"], spacing.doubleValue ?? -1 < 0 {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.spacing",
                message: "section spacing must be >= 0"
            ))
        }
        return issues
    }

    func makeView(component: ComponentSpec, context: RenderContext) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = component.props["spacing"]?.doubleValue ?? 8
        stack.alignment = .fill

        // Optional section title
        if let title = component.props["title"]?.stringValue, !title.isEmpty {
            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
            titleLabel.textColor = .secondaryLabel
            stack.addArrangedSubview(titleLabel)
        }

        // Render children using the registry
        if let children = component.children {
            for child in children {
                guard let definition = context.eventBridge.registry.componentDefinition(for: child.type) else {
                    continue
                }
                let childView = definition.makeView(component: child, context: context)
                stack.addArrangedSubview(childView)
            }
        }

        return stack
    }
}
