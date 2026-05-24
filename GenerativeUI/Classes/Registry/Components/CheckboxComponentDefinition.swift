import UIKit

/// Definition for the `checkbox` component type.
/// Renders a toggleable checkbox with label, bound to a boolean state key.
/// Uses UIButton to simulate checkbox behavior (compatible with iOS 15+).
internal final class CheckboxComponentDefinition: ComponentDefinition {
    let type: ComponentType = .checkbox
    let category: ComponentCategory = .interactive
    let allowsChildren = false
    let supportedEvents: Set<EventType> = [.valueChanged]
    let requiredProps: Set<String> = ["label", "binding"]

    func validate(props: [String: JSONValue]) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        if let label = props["label"]?.stringValue {
            if label.trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append(ValidationIssue(
                    code: .invalidProps,
                    path: "props.label",
                    message: "checkbox label must be a non-empty string"
                ))
            }
        } else {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.label",
                message: "checkbox requires a string 'label' prop"
            ))
        }

        if props["binding"]?.stringValue == nil {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.binding",
                message: "checkbox requires a string 'binding' prop"
            ))
        }

        return issues
    }

    func makeView(component: ComponentSpec, context: RenderContext) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 4

        let binding = component.props["binding"]?.stringValue ?? ""
        let isChecked = context.stateStore.value(for: binding)?.boolValue ?? false

        // Checkbox button
        let checkboxButton = GUICheckboxButton(type: .system)
        checkboxButton.contentHorizontalAlignment = .leading
        checkboxButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        checkboxButton.titleLabel?.numberOfLines = 0

        let label = component.props["label"]?.stringValue ?? ""
        checkboxButton.setTitle("  \(label)", for: .normal)
        checkboxButton.setTitleColor(.label, for: .normal)

        checkboxButton.isCheckedState = isChecked
        checkboxButton.componentId = component.id
        checkboxButton.bindingKey = binding
        checkboxButton.context = context
        Self.applyCheckboxStyle(to: checkboxButton, checked: isChecked)

        checkboxButton.addTarget(checkboxButton, action: #selector(GUICheckboxButton.checkboxTapped), for: .touchUpInside)
        container.addArrangedSubview(checkboxButton)

        // Optional helper text
        if let helperText = component.props["helperText"]?.stringValue, !helperText.isEmpty {
            let helperLabel = UILabel()
            helperLabel.text = helperText
            helperLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
            helperLabel.textColor = .secondaryLabel
            helperLabel.numberOfLines = 0
            container.addArrangedSubview(helperLabel)
        }

        return container
    }

    // MARK: - Helpers

    fileprivate static func applyCheckboxStyle(to button: GUICheckboxButton, checked: Bool) {
        let imageName = checked ? "checkmark.square.fill" : "square"
        let color: UIColor = checked ? .systemBlue : .secondaryLabel
        let image = UIImage(systemName: imageName)?.withTintColor(color, renderingMode: .alwaysOriginal)
        button.setImage(image, for: .normal)
    }
}

// MARK: - Internal Checkbox Button Subclass

/// A UIButton subclass that maintains checkbox toggle state and dispatches events.
final class GUICheckboxButton: UIButton {
    var isCheckedState: Bool = false
    var componentId: String = ""
    var bindingKey: String = ""
    weak var context: RenderContext?

    @objc func checkboxTapped() {
        guard let context = context else { return }
        isCheckedState.toggle()

        let newValue = JSONValue.bool(isCheckedState)
        context.stateStore.setValue(newValue, for: bindingKey)

        CheckboxComponentDefinition.applyCheckboxStyle(to: self, checked: isCheckedState)

        context.eventBridge.sendValueChanged(
            specId: context.specId,
            componentId: componentId,
            binding: bindingKey,
            value: newValue,
            state: context.stateStore.currentValues
        )
    }
}
