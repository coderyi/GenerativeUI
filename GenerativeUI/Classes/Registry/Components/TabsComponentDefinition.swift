import UIKit

/// Definition for the `tabs` component type.
/// Renders a `UISegmentedControl` header with switchable content areas.
///
/// Each tab item has an `id`, `title`, and `children` component array.
/// Switching tabs replaces the content area's subviews.
/// Optionally writes the selected tab id to state via `binding`.
internal final class TabsComponentDefinition: ComponentDefinition {
    let type: ComponentType = .tabs
    let category: ComponentCategory = .interactive
    let allowsChildren = false
    let supportedEvents: Set<EventType> = [.valueChanged]
    let requiredProps: Set<String> = ["items"]

    func validate(props: [String: JSONValue]) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        guard let items = props["items"]?.arrayValue else {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.items",
                message: "tabs requires an array 'items' prop"
            ))
            return issues
        }

        if items.count < 2 {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.items",
                message: "tabs items must have at least 2 entries"
            ))
        }

        var seenIds: Set<String> = []
        for (index, item) in items.enumerated() {
            guard let obj = item.objectValue else {
                issues.append(ValidationIssue(
                    code: .invalidProps,
                    path: "props.items[\(index)]",
                    message: "each tab item must be an object"
                ))
                continue
            }

            // id
            if let id = obj["id"]?.stringValue {
                if seenIds.contains(id) {
                    issues.append(ValidationIssue(
                        code: .invalidProps,
                        path: "props.items[\(index)].id",
                        message: "duplicate tab id '\(id)'"
                    ))
                }
                seenIds.insert(id)
            } else {
                issues.append(ValidationIssue(
                    code: .invalidProps,
                    path: "props.items[\(index)].id",
                    message: "tab item requires a string 'id'"
                ))
            }

            // title
            if let title = obj["title"]?.stringValue {
                if title.trimmingCharacters(in: .whitespaces).isEmpty {
                    issues.append(ValidationIssue(
                        code: .invalidProps,
                        path: "props.items[\(index)].title",
                        message: "tab item title must be non-empty"
                    ))
                }
            } else {
                issues.append(ValidationIssue(
                    code: .invalidProps,
                    path: "props.items[\(index)].title",
                    message: "tab item requires a string 'title'"
                ))
            }

            // children — must be an array if present (allowed to be empty)
            if let children = obj["children"] {
                if children.arrayValue == nil {
                    issues.append(ValidationIssue(
                        code: .invalidProps,
                        path: "props.items[\(index)].children",
                        message: "tab item children must be an array"
                    ))
                }
            }
        }

        return issues
    }

    func makeView(component: ComponentSpec, context: RenderContext) -> UIView {
        let items = Self.parseTabItems(from: component.props["items"])
        let binding = component.props["binding"]?.stringValue

        let container = UIView()

        // Segmented control
        let segmentedControl = UISegmentedControl(items: items.map { $0.title })
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(segmentedControl)

        // Content area
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(contentView)

        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: container.topAnchor),
            segmentedControl.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            segmentedControl.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            contentView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 12),
            contentView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        // Render initial tab content
        if !items.isEmpty {
            Self.renderTabContent(items[0].children, into: contentView, context: context)

            // Write initial binding value
            if let binding = binding {
                context.stateStore.setValue(.string(items[0].id), for: binding)
            }
        }

        // Set up tab switching via handler object
        let handler = GUITabsHandler(
            items: items,
            contentView: contentView,
            context: context,
            componentId: component.id,
            binding: binding
        )
        segmentedControl.guiTabsHandler = handler
        segmentedControl.addTarget(handler, action: #selector(GUITabsHandler.tabChanged(_:)), for: .valueChanged)

        return container
    }

    // MARK: - Tab Item Parsing

    struct TabItem {
        let id: String
        let title: String
        let children: [ComponentSpec]
    }

    static func parseTabItems(from value: JSONValue?) -> [TabItem] {
        guard let items = value?.arrayValue else { return [] }
        return items.compactMap { item -> TabItem? in
            guard let obj = item.objectValue,
                  let id = obj["id"]?.stringValue,
                  let title = obj["title"]?.stringValue else { return nil }

            let children: [ComponentSpec]
            if let childrenArray = obj["children"]?.arrayValue {
                children = childrenArray.compactMap { Self.parseComponentSpec(from: $0) }
            } else {
                children = []
            }
            return TabItem(id: id, title: title, children: children)
        }
    }

    /// Parses a JSONValue into a ComponentSpec (used for tab children which are nested in props).
    private static func parseComponentSpec(from value: JSONValue) -> ComponentSpec? {
        guard let obj = value.objectValue,
              let id = obj["id"]?.stringValue,
              let type = obj["type"]?.stringValue else { return nil }

        // Parse props
        var props: [String: JSONValue] = [:]
        if let propsObj = obj["props"]?.objectValue {
            props = propsObj
        }

        // Parse action
        var action: ActionSpec?
        if let actionObj = obj["action"]?.objectValue, let actionId = actionObj["id"]?.stringValue {
            action = ActionSpec(id: actionId)
        }

        // Parse children recursively
        var children: [ComponentSpec]?
        if let childrenArray = obj["children"]?.arrayValue {
            children = childrenArray.compactMap { parseComponentSpec(from: $0) }
        }

        return ComponentSpec(id: id, type: type, props: props, action: action, children: children)
    }

    // MARK: - Content Rendering

    fileprivate static func renderTabContent(_ children: [ComponentSpec], into contentView: UIView, context: RenderContext) {
        // Clear existing content
        contentView.subviews.forEach { $0.removeFromSuperview() }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        for child in children {
            guard let definition = context.eventBridge.registry.componentDefinition(for: child.type) else {
                GenerativeUILogger.shared.warning(
                    "Skipping unregistered component type in tabs",
                    fields: ["component_id": child.id, "type": child.type]
                )
                continue
            }
            let childView = definition.makeView(component: child, context: context)
            stack.addArrangedSubview(childView)
        }

        // Tab content is often embedded in auto-sized containers. Mark the
        // swapped subtree dirty so outer layout can recompute the final height.
        stack.setNeedsLayout()
        contentView.setNeedsLayout()
        contentView.invalidateIntrinsicContentSize()
        contentView.superview?.setNeedsLayout()
        contentView.superview?.invalidateIntrinsicContentSize()
    }
}

// MARK: - Internal Tab Handler

/// Handles UISegmentedControl value changes and swaps tab content.
/// Stored as an associated object on the segmented control to maintain its lifecycle.
final class GUITabsHandler: NSObject {
    let items: [TabsComponentDefinition.TabItem]
    weak var contentView: UIView?
    weak var context: RenderContext?
    let componentId: String
    let binding: String?

    init(items: [TabsComponentDefinition.TabItem], contentView: UIView, context: RenderContext, componentId: String, binding: String?) {
        self.items = items
        self.contentView = contentView
        self.context = context
        self.componentId = componentId
        self.binding = binding
    }

    @objc func tabChanged(_ sender: UISegmentedControl) {
        guard let context = context,
              let contentView = contentView,
              sender.selectedSegmentIndex < items.count else { return }

        let selectedItem = items[sender.selectedSegmentIndex]

        // Swap content
        TabsComponentDefinition.renderTabContent(selectedItem.children, into: contentView, context: context)

        // Update binding and dispatch event only when binding is configured
        if let binding = binding {
            context.stateStore.setValue(.string(selectedItem.id), for: binding)
            context.eventBridge.sendValueChanged(
                specId: context.specId,
                componentId: componentId,
                binding: binding,
                value: .string(selectedItem.id),
                state: context.stateStore.currentValues
            )
        }
    }
}

// MARK: - Associated Object for Handler Lifecycle

private var tabsHandlerKey: UInt8 = 0

private extension UISegmentedControl {
    var guiTabsHandler: GUITabsHandler? {
        get { objc_getAssociatedObject(self, &tabsHandlerKey) as? GUITabsHandler }
        set { objc_setAssociatedObject(self, &tabsHandlerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}
