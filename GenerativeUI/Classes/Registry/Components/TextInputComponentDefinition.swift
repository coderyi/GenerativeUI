import UIKit

/// Definition for the `textInput` component type.
/// Renders a labeled single-line text field bound to a state key.
internal final class TextInputComponentDefinition: ComponentDefinition {
    let type: ComponentType = .textInput
    let category: ComponentCategory = .interactive
    let allowsChildren = false
    let supportedEvents: Set<EventType> = [.valueChanged]
    let requiredProps: Set<String> = ["label", "binding"]

    func validate(props: [String: JSONValue]) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if props["label"]?.stringValue == nil {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.label",
                message: "textInput requires a string 'label' prop"
            ))
        }
        if props["binding"]?.stringValue == nil {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.binding",
                message: "textInput requires a string 'binding' prop"
            ))
        }
        return issues
    }

    func makeView(component: ComponentSpec, context: RenderContext) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 6

        // Label
        let label = UILabel()
        label.text = component.props["label"]?.stringValue ?? ""
        label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        container.addArrangedSubview(label)

        // Text field
        let textField = GUITextField()
        textField.borderStyle = .roundedRect
        textField.font = UIFont.systemFont(ofSize: 17)
        textField.placeholder = component.props["placeholder"]?.stringValue

        // Set keyboard type
        if let keyboardType = component.props["keyboardType"]?.stringValue {
            switch keyboardType {
            case "number": textField.keyboardType = .numberPad
            case "email": textField.keyboardType = .emailAddress
            case "phone": textField.keyboardType = .phonePad
            case "url": textField.keyboardType = .URL
            default: textField.keyboardType = .default
            }
        }

        // Bind current value from state
        let binding = component.props["binding"]?.stringValue ?? ""
        if let currentValue = context.stateStore.value(for: binding)?.stringValue {
            textField.text = currentValue
        }

        // Set up change handler
        textField.componentId = component.id
        textField.bindingKey = binding
        textField.context = context
        textField.addTarget(textField, action: #selector(GUITextField.textDidChange), for: .editingChanged)

        // Height constraint to ensure the text field is not compressed
        textField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        container.addArrangedSubview(textField)

        return container
    }
}

// MARK: - Internal TextField Subclass

/// A UITextField subclass that captures component context for event dispatch.
final class GUITextField: UITextField {
    var componentId: String = ""
    var bindingKey: String = ""
    weak var context: RenderContext?

    @objc func textDidChange() {
        guard let context = context else { return }
        let newValue = JSONValue.string(text ?? "")
        context.stateStore.setValue(newValue, for: bindingKey)
        context.eventBridge.sendValueChanged(
            specId: context.specId,
            componentId: componentId,
            binding: bindingKey,
            value: newValue,
            state: context.stateStore.currentValues
        )
    }
}
