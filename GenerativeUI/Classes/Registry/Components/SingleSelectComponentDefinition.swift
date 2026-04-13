import UIKit

/// Definition for the `singleSelect` component type.
/// Renders a labeled set of selectable options, bound to a state key.
internal final class SingleSelectComponentDefinition: ComponentDefinition {
    let type: ComponentType = .singleSelect
    let category: ComponentCategory = .interactive
    let allowsChildren = false
    let supportedEvents: Set<EventType> = [.valueChanged]
    let requiredProps: Set<String> = ["label", "binding", "options"]

    func validate(props: [String: JSONValue]) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        if props["label"]?.stringValue == nil {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.label",
                message: "singleSelect requires a string 'label' prop"
            ))
        }
        if props["binding"]?.stringValue == nil {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.binding",
                message: "singleSelect requires a string 'binding' prop"
            ))
        }
        if let options = props["options"]?.arrayValue {
            for (index, option) in options.enumerated() {
                guard let obj = option.objectValue,
                      obj["label"]?.stringValue != nil,
                      obj["value"]?.stringValue != nil else {
                    issues.append(ValidationIssue(
                        code: .invalidProps,
                        path: "props.options[\(index)]",
                        message: "each option must have 'label' and 'value' string fields"
                    ))
                    continue
                }
            }
        } else {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.options",
                message: "singleSelect requires an array 'options' prop"
            ))
        }
        if let cornerRadius = props["cornerRadius"], cornerRadius.doubleValue ?? -1 < 0 {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.cornerRadius",
                message: "singleSelect cornerRadius must be >= 0"
            ))
        }
        return issues
    }

    func makeView(component: ComponentSpec, context: RenderContext) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 8

        // Label
        let label = UILabel()
        label.text = component.props["label"]?.stringValue ?? ""
        label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        container.addArrangedSubview(label)

        // Helper text
        if let helperText = component.props["helperText"]?.stringValue, !helperText.isEmpty {
            let helperLabel = UILabel()
            helperLabel.text = helperText
            helperLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
            helperLabel.textColor = .secondaryLabel
            helperLabel.numberOfLines = 0
            container.addArrangedSubview(helperLabel)
        }

        // Options
        let binding = component.props["binding"]?.stringValue ?? ""
        let currentValue = context.stateStore.value(for: binding)?.stringValue

        if let options = component.props["options"]?.arrayValue {
            for option in options {
                guard let obj = option.objectValue,
                      let optionLabel = obj["label"]?.stringValue,
                      let optionValue = obj["value"]?.stringValue else { continue }

                let optionButton = GUIOptionButton(type: .system)
                optionButton.setTitle(optionLabel, for: .normal)
                optionButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)
                optionButton.contentHorizontalAlignment = .leading
                optionButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
                optionButton.layer.cornerRadius = component.props["cornerRadius"]?.doubleValue ?? 8
                optionButton.layer.borderWidth = 1

                let isSelected = currentValue == optionValue
                applyOptionStyle(to: optionButton, selected: isSelected)

                optionButton.optionValue = optionValue
                optionButton.componentId = component.id
                optionButton.bindingKey = binding
                optionButton.context = context
                optionButton.parentContainer = container
                optionButton.addTarget(optionButton, action: #selector(GUIOptionButton.optionTapped), for: .touchUpInside)

                container.addArrangedSubview(optionButton)
            }
        }

        return container
    }
}

private func applyOptionStyle(to button: UIButton, selected: Bool) {
    if selected {
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        button.layer.borderColor = UIColor.systemBlue.cgColor
        button.setTitleColor(.systemBlue, for: .normal)
    } else {
        button.backgroundColor = .secondarySystemBackground
        button.layer.borderColor = UIColor.separator.cgColor
        button.setTitleColor(.label, for: .normal)
    }
}

// MARK: - Internal Option Button Subclass

/// A UIButton subclass representing a single option in a singleSelect.
final class GUIOptionButton: UIButton {
    var optionValue: String = ""
    var componentId: String = ""
    var bindingKey: String = ""
    weak var context: RenderContext?
    weak var parentContainer: UIStackView?

    @objc func optionTapped() {
        guard let context = context else { return }
        let newValue = JSONValue.string(optionValue)
        context.stateStore.setValue(newValue, for: bindingKey)

        // Update visual state of all sibling options
        if let container = parentContainer {
            for view in container.arrangedSubviews {
                if let optionBtn = view as? GUIOptionButton {
                    applyOptionStyle(to: optionBtn, selected: optionBtn.optionValue == optionValue)
                }
            }
        }

        context.eventBridge.sendValueChanged(
            specId: context.specId,
            componentId: componentId,
            binding: bindingKey,
            value: newValue,
            state: context.stateStore.currentValues
        )
    }
}
