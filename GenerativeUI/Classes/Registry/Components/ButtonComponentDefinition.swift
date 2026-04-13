import UIKit

/// Definition for the `button` component type.
/// Renders a tappable button that triggers an action.
internal final class ButtonComponentDefinition: ComponentDefinition {
    let type: ComponentType = .button
    let category: ComponentCategory = .interactive
    let allowsChildren = false
    let supportedEvents: Set<EventType> = [.actionTriggered]
    let requiredProps: Set<String> = ["label"]

    func validate(props: [String: JSONValue]) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if props["label"]?.stringValue == nil {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.label",
                message: "button requires a string 'label' prop"
            ))
        }
        if let cornerRadius = props["cornerRadius"], cornerRadius.doubleValue ?? -1 < 0 {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.cornerRadius",
                message: "button cornerRadius must be >= 0"
            ))
        }
        if let fontSize = props["fontSize"], fontSize.doubleValue ?? 0 <= 0 {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.fontSize",
                message: "button fontSize must be > 0"
            ))
        }
        if let style = props["style"] {
            let allowed = ["primary", "secondary", "text"]
            if let styleStr = style.stringValue, !allowed.contains(styleStr) {
                issues.append(ValidationIssue(
                    code: .invalidProps,
                    path: "props.style",
                    message: "button style must be one of: \(allowed.joined(separator: ", "))"
                ))
            }
        }
        return issues
    }

    func makeView(component: ComponentSpec, context: RenderContext) -> UIView {
        let button = GUIButton(type: .system)
        button.setTitle(component.props["label"]?.stringValue ?? "", for: .normal)

        let fontSize = component.props["fontSize"]?.doubleValue ?? 17
        button.titleLabel?.font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 24, bottom: 14, right: 24)
        button.layer.cornerRadius = component.props["cornerRadius"]?.doubleValue ?? 10

        let style = component.props["style"]?.stringValue ?? "primary"
        switch style {
        case "primary":
            button.backgroundColor = .systemBlue
            button.setTitleColor(.white, for: .normal)
        case "secondary":
            button.backgroundColor = .secondarySystemBackground
            button.setTitleColor(.systemBlue, for: .normal)
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.systemBlue.cgColor
        default: // "text"
            button.backgroundColor = .clear
            button.setTitleColor(.systemBlue, for: .normal)
        }

        button.componentId = component.id
        button.actionId = component.action?.id
        button.context = context
        button.addTarget(button, action: #selector(GUIButton.buttonTapped), for: .touchUpInside)

        return button
    }
}

// MARK: - Internal Button Subclass

/// A UIButton subclass that captures component context for event dispatch.
final class GUIButton: UIButton {
    var componentId: String = ""
    var actionId: String?
    weak var context: RenderContext?

    @objc func buttonTapped() {
        guard let context = context else { return }
        context.eventBridge.sendActionTriggered(
            specId: context.specId,
            componentId: componentId,
            actionId: actionId,
            state: context.stateStore.currentValues
        )
    }
}
