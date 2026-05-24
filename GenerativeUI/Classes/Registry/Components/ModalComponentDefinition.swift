import UIKit

/// Definition for the `modal` component type.
/// Renders an inline expandable panel as the current fallback implementation.
///
/// Full modal presentation (via `present`) will be implemented in a future version
/// when surface lifecycle management is available. Currently the modal component
/// renders a trigger button that toggles an inline content area.
internal final class ModalComponentDefinition: ComponentDefinition {
    let type: ComponentType = .modal
    let category: ComponentCategory = .interactive
    let allowsChildren = true
    let supportedEvents: Set<EventType> = [.actionTriggered]
    let requiredProps: Set<String> = ["triggerLabel"]

    func validate(props: [String: JSONValue]) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        if let triggerLabel = props["triggerLabel"]?.stringValue {
            if triggerLabel.trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append(ValidationIssue(
                    code: .invalidProps,
                    path: "props.triggerLabel",
                    message: "modal triggerLabel must be a non-empty string"
                ))
            }
        } else {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.triggerLabel",
                message: "modal requires a string 'triggerLabel' prop"
            ))
        }

        if let cornerRadius = props["cornerRadius"], cornerRadius.doubleValue ?? -1 < 0 {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.cornerRadius",
                message: "modal cornerRadius must be >= 0"
            ))
        }

        return issues
    }

    func makeView(component: ComponentSpec, context: RenderContext) -> UIView {
        let outerContainer = UIStackView()
        outerContainer.axis = .vertical
        outerContainer.spacing = 0
        outerContainer.alignment = .fill

        // Trigger button
        let triggerLabel = component.props["triggerLabel"]?.stringValue ?? ""
        let triggerButton = GUIModalTriggerButton(type: .system)
        triggerButton.setTitle(triggerLabel, for: .normal)
        triggerButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        triggerButton.setTitleColor(.systemBlue, for: .normal)
        triggerButton.contentHorizontalAlignment = .leading
        var triggerConfiguration = UIButton.Configuration.plain()
        triggerConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0)
        triggerButton.configuration = triggerConfiguration
        outerContainer.addArrangedSubview(triggerButton)

        // Expandable content panel (initially hidden)
        let contentPanel = UIView()
        contentPanel.backgroundColor = .secondarySystemBackground
        contentPanel.layer.cornerRadius = component.props["cornerRadius"]?.doubleValue ?? 10
        contentPanel.clipsToBounds = true
        contentPanel.isHidden = true

        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 8
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentPanel.addSubview(contentStack)

        let padding: CGFloat = 16
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: contentPanel.topAnchor, constant: padding),
            contentStack.leadingAnchor.constraint(equalTo: contentPanel.leadingAnchor, constant: padding),
            contentStack.trailingAnchor.constraint(equalTo: contentPanel.trailingAnchor, constant: -padding),
            contentStack.bottomAnchor.constraint(equalTo: contentPanel.bottomAnchor, constant: -padding)
        ])

        // Optional title
        if let title = component.props["title"]?.stringValue, !title.isEmpty {
            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
            contentStack.addArrangedSubview(titleLabel)
        }

        // Render children
        if let children = component.children {
            for child in children {
                guard let definition = context.eventBridge.registry.componentDefinition(for: child.type) else {
                    GenerativeUILogger.shared.warning(
                        "Skipping unregistered component type in modal",
                        fields: ["component_id": child.id, "type": child.type]
                    )
                    continue
                }
                let childView = definition.makeView(component: child, context: context)
                contentStack.addArrangedSubview(childView)
            }
        }

        // Optional primary action button
        if let primaryLabel = component.props["primaryActionLabel"]?.stringValue, !primaryLabel.isEmpty {
            let actionButton = GUIButton(type: .system)
            actionButton.setTitle(primaryLabel, for: .normal)
            actionButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
            var actionConfiguration = UIButton.Configuration.plain()
            actionConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24)
            actionButton.configuration = actionConfiguration
            actionButton.layer.cornerRadius = 8
            actionButton.backgroundColor = .systemBlue
            actionButton.setTitleColor(.white, for: .normal)
            actionButton.componentId = component.id
            actionButton.actionId = component.action?.id
            actionButton.context = context
            actionButton.addTarget(actionButton, action: #selector(GUIButton.buttonTapped), for: .touchUpInside)
            contentStack.addArrangedSubview(actionButton)
        }

        outerContainer.addArrangedSubview(contentPanel)

        // Wire trigger to toggle content panel
        triggerButton.contentPanel = contentPanel
        triggerButton.addTarget(triggerButton, action: #selector(GUIModalTriggerButton.triggerTapped), for: .touchUpInside)

        return outerContainer
    }
}

// MARK: - Internal Trigger Button Subclass

/// A UIButton subclass that toggles the visibility of modal content.
final class GUIModalTriggerButton: UIButton {
    weak var contentPanel: UIView?

    @objc func triggerTapped() {
        guard let panel = contentPanel else { return }
        UIView.animate(withDuration: 0.25) {
            panel.isHidden.toggle()
            panel.alpha = panel.isHidden ? 0 : 1
            panel.superview?.layoutIfNeeded()
        }
    }
}
