import UIKit

/// Definition for the `text` component type.
/// Renders static text with optional style (title, headline, body, caption).
internal final class TextComponentDefinition: ComponentDefinition {
    let type: ComponentType = .text
    let category: ComponentCategory = .display
    let allowsChildren = false
    let supportedEvents: Set<EventType> = []
    let requiredProps: Set<String> = ["text"]

    func validate(props: [String: JSONValue]) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if props["text"]?.stringValue == nil {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.text",
                message: "text component requires a string 'text' prop"
            ))
        }
        if let fontSize = props["fontSize"], fontSize.doubleValue ?? 0 <= 0 {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.fontSize",
                message: "text fontSize must be > 0"
            ))
        }
        if let style = props["style"] {
            let allowed = ["title", "headline", "body", "caption"]
            if let styleStr = style.stringValue, !allowed.contains(styleStr) {
                issues.append(ValidationIssue(
                    code: .invalidProps,
                    path: "props.style",
                    message: "text style must be one of: \(allowed.joined(separator: ", "))"
                ))
            }
        }
        return issues
    }

    func makeView(component: ComponentSpec, context: RenderContext) -> UIView {
        let label = UILabel()
        label.numberOfLines = 0
        label.text = component.props["text"]?.stringValue ?? ""

        let style = component.props["style"]?.stringValue ?? "body"
        let fontSizeOverride = component.props["fontSize"]?.doubleValue

        switch style {
        case "title":
            label.font = UIFont.systemFont(ofSize: fontSizeOverride ?? 28, weight: .bold)
        case "headline":
            label.font = UIFont.systemFont(ofSize: fontSizeOverride ?? 20, weight: .semibold)
        case "caption":
            label.font = UIFont.systemFont(ofSize: fontSizeOverride ?? 13, weight: .regular)
            label.textColor = .secondaryLabel
        default: // "body"
            label.font = UIFont.systemFont(ofSize: fontSizeOverride ?? 17, weight: .regular)
        }

        return label
    }
}
