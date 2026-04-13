import UIKit

/// Definition for the `column` component type.
/// A vertical layout container that stacks children from top to bottom.
///
/// Compared to `section`, `column` offers explicit `spacing` and `alignment` control.
/// `section` is kept as-is for backward compatibility.
///
/// Supported props:
/// - `spacing` (Number, default 8): space between children in points.
/// - `alignment` (String, default "fill"): horizontal alignment — "leading", "center", "trailing", "fill".
internal final class ColumnComponentDefinition: ComponentDefinition {
    let type: ComponentType = .column
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
                message: "column spacing must be >= 0"
            ))
        }
        return issues
    }

    func makeView(component: ComponentSpec, context: RenderContext) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = component.props["spacing"]?.doubleValue ?? 8
        stack.alignment = Self.mapAlignment(component.props["alignment"]?.stringValue)

        guard let children = component.children else { return stack }
        for child in children {
            guard let definition = context.eventBridge.registry.componentDefinition(for: child.type) else {
                GenerativeUILogger.shared.warning(
                    "Skipping unregistered component type in column",
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

    /// Maps a JSON alignment string to UIStackView.Alignment for vertical axis.
    /// Unknown values silently fall back to the default (.fill).
    private static func mapAlignment(_ value: String?) -> UIStackView.Alignment {
        switch value {
        case "leading":  return .leading
        case "center":   return .center
        case "trailing": return .trailing
        default:         return .fill
        }
    }

}
