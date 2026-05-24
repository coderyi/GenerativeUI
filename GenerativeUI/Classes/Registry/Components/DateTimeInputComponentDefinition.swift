import UIKit

/// Definition for the `dateTimeInput` component type.
/// Renders a labeled `UIDatePicker` bound to a state key, outputting ISO8601 strings.
internal final class DateTimeInputComponentDefinition: ComponentDefinition {
    let type: ComponentType = .dateTimeInput
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
                message: "dateTimeInput requires a string 'label' prop"
            ))
        }
        if props["binding"]?.stringValue == nil {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.binding",
                message: "dateTimeInput requires a string 'binding' prop"
            ))
        }

        // Validate mode
        if let mode = props["mode"]?.stringValue {
            let allowed = ["date", "time", "dateTime"]
            if !allowed.contains(mode) {
                issues.append(ValidationIssue(
                    code: .invalidProps,
                    path: "props.mode",
                    message: "dateTimeInput mode must be one of: \(allowed.joined(separator: ", "))"
                ))
            }
        }

        // Validate date strings are parseable
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var minDate: Date?
        var maxDate: Date?

        if let minStr = props["minimumDate"]?.stringValue {
            if let parsed = formatter.date(from: minStr) ?? ISO8601DateFormatter().date(from: minStr) {
                minDate = parsed
            } else {
                issues.append(ValidationIssue(
                    code: .invalidProps,
                    path: "props.minimumDate",
                    message: "minimumDate must be a valid ISO8601 string"
                ))
            }
        }
        if let maxStr = props["maximumDate"]?.stringValue {
            if let parsed = formatter.date(from: maxStr) ?? ISO8601DateFormatter().date(from: maxStr) {
                maxDate = parsed
            } else {
                issues.append(ValidationIssue(
                    code: .invalidProps,
                    path: "props.maximumDate",
                    message: "maximumDate must be a valid ISO8601 string"
                ))
            }
        }

        if let min = minDate, let max = maxDate, min > max {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.minimumDate",
                message: "minimumDate must be <= maximumDate"
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

        // Date picker
        let datePicker = GUIDatePicker()
        datePicker.preferredDatePickerStyle = .compact

        // Map mode
        let mode = component.props["mode"]?.stringValue ?? "dateTime"
        switch mode {
        case "date": datePicker.datePickerMode = .date
        case "time": datePicker.datePickerMode = .time
        default:     datePicker.datePickerMode = .dateAndTime
        }

        // Min / max constraints
        let formatter = ISO8601DateFormatter()
        if let minStr = component.props["minimumDate"]?.stringValue {
            datePicker.minimumDate = formatter.date(from: minStr)
        }
        if let maxStr = component.props["maximumDate"]?.stringValue {
            datePicker.maximumDate = formatter.date(from: maxStr)
        }

        // Restore current value from state
        let binding = component.props["binding"]?.stringValue ?? ""
        if let currentStr = context.stateStore.value(for: binding)?.stringValue,
           let currentDate = formatter.date(from: currentStr) {
            datePicker.date = currentDate
        }

        // Event binding
        datePicker.componentId = component.id
        datePicker.bindingKey = binding
        datePicker.context = context
        datePicker.addTarget(datePicker, action: #selector(GUIDatePicker.dateDidChange), for: .valueChanged)

        container.addArrangedSubview(datePicker)

        return container
    }
}

// MARK: - Internal DatePicker Subclass

/// A UIDatePicker subclass that captures component context for state updates and event dispatch.
final class GUIDatePicker: UIDatePicker {
    var componentId: String = ""
    var bindingKey: String = ""
    weak var context: RenderContext?

    private let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    @objc func dateDidChange() {
        guard let context = context else { return }
        let dateString = iso8601Formatter.string(from: date)
        let newValue = JSONValue.string(dateString)

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
