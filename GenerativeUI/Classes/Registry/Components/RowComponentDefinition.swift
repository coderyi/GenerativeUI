import UIKit

/// Definition for the `row` component type.
/// A horizontal layout container that arranges children side by side.
///
/// Supported props:
/// - `spacing` (Number, default 8): space between children in points.
/// - `alignment` (String, default "center"): vertical alignment — "top", "center", "bottom", "fill".
internal final class RowComponentDefinition: ComponentDefinition {
    let type: ComponentType = .row
    let category: ComponentCategory = .layout
    let allowsChildren = true
    let supportedEvents: Set<EventType> = []
    let requiredProps: Set<String> = []

    func validate(props: [String: JSONValue]) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if let spacing = props["spacing"], spacing.doubleValue ?? 0 < 0 {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.spacing",
                message: "row spacing must be >= 0"
            ))
        }
        return issues
    }

    func makeView(component: ComponentSpec, context: RenderContext) -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = component.props["spacing"]?.doubleValue ?? 8
        stack.alignment = Self.mapAlignment(component.props["alignment"]?.stringValue)

        guard let children = component.children else { return stack }
        for child in children {
            guard let definition = context.eventBridge.registry.componentDefinition(for: child.type) else {
                GenerativeUILogger.shared.warning(
                    "Skipping unregistered component type in row",
                    fields: ["component_id": child.id, "type": child.type]
                )
                continue
            }
            let childView = definition.makeView(component: child, context: context)
            stack.addArrangedSubview(childView)
        }

        return stack
    }

    // MARK: - Helpers

    /// Maps a JSON alignment string to UIStackView.Alignment for horizontal axis.
    /// Unknown values silently fall back to the default (.center).
    private static func mapAlignment(_ value: String?) -> UIStackView.Alignment {
        switch value {
        case "top":    return .top
        case "bottom": return .bottom
        case "fill":   return .fill
        default:       return .center
        }
    }

}
