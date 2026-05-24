import UIKit

/// A lightweight UIView container that renders a `ViewSpec` component tree.
///
/// Unlike `GenerativeScreenViewController` which uses `UICollectionView` for full-page rendering,
/// `GenerativeViewRenderer` uses a vertical `UIStackView` — simpler, supports intrinsic content size,
/// and suitable for embedding into any parent view.
///
/// Usage:
/// ```swift
/// let renderer = GenerativeViewRenderer()
/// renderer.render(spec: viewSpec, runtime: runtime)
/// renderer.onEvent = { envelope in ... }
/// parentView.addSubview(renderer)
/// ```
public final class GenerativeViewRenderer: UIView {

    /// Called when the user interacts with any component in this view.
    public var onEvent: ((InteractionEnvelope) -> Void)?

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var stateStore: StateStore?
    private var eventBridge: EventBridge?
    private var renderContext: RenderContext?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupStackView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Renders the given `ViewSpec` using the provided runtime's registry.
    ///
    /// This method clears any previously rendered content and rebuilds the component tree.
    /// Each view gets its own isolated `StateStore` and `EventBridge`, so rendering a view
    /// never affects the state of other screens or views.
    public func render(spec: ViewSpec, runtime: GenerativeUIRuntime) {
        // Clear previous content
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Create isolated state and event bridge for this view.
        // This avoids overwriting the runtime's shared stateStore/eventBridge,
        // which may be in use by a screen or another view.
        let initialState = spec.state ?? [:]
        let localStateStore = StateStore(initialValues: initialState)
        let localEventBridge = EventBridge(registry: runtime.registry)
        localEventBridge.onEvent = { [weak self] envelope in
            self?.onEvent?(envelope)
        }

        self.stateStore = localStateStore
        self.eventBridge = localEventBridge

        let context = RenderContext(
            specId: spec.id,
            stateStore: localStateStore,
            eventBridge: localEventBridge
        )
        self.renderContext = context

        for component in spec.components {
            if let definition = runtime.registry.componentDefinition(for: component.type) {
                let componentView = definition.makeView(component: component, context: context)
                stackView.addArrangedSubview(componentView)
            } else {
                GenerativeUILogger.shared.warning(
                    "Skipping unregistered component type",
                    fields: ["view_id": spec.id, "component_id": component.id, "type": component.type]
                )
            }
        }

        GenerativeUILogger.shared.info(
            "View rendered",
            fields: ["view_id": spec.id, "component_count": "\(spec.components.count)"]
        )
    }

    private func setupStackView() {
        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
}

// MARK: - Container View Controller

/// A thin UIViewController wrapper around `GenerativeViewRenderer`.
/// Use this when you need ViewController lifecycle (e.g., presenting as a sheet or modal).
public final class GenerativeViewContainerController: UIViewController {

    /// The underlying renderer view.
    public let renderer: GenerativeViewRenderer

    public init(renderer: GenerativeViewRenderer) {
        self.renderer = renderer
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        renderer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(renderer)
        NSLayoutConstraint.activate([
            renderer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            renderer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            renderer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            renderer.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
}
