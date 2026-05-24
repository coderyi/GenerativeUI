import UIKit

/// The main view controller for rendering a generative UI screen.
/// Uses `UICollectionView` as the page-level rendering backbone.
public final class GenerativeScreenViewController: UIViewController {

    /// The screen specification to render.
    public let spec: ScreenSpec

    /// The runtime that provides registry, state, and event bridging.
    public let runtime: GenerativeUIRuntime

    /// Called when the user interacts with the screen.
    public let onEvent: (InteractionEnvelope) -> Void

    private var collectionView: UICollectionView!
    private var renderSections: [RenderSection] = []
    private var renderContext: RenderContext!

    private static let cellReuseId = "GUIComponentCell"
    private static let headerReuseId = "GUISectionHeader"

    public init(
        spec: ScreenSpec,
        runtime: GenerativeUIRuntime,
        onEvent: @escaping (InteractionEnvelope) -> Void
    ) {
        self.spec = spec
        self.runtime = runtime
        self.onEvent = onEvent
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // Set up navigation title
        if let nav = navigationController {
            navigationItem.title = spec.title
            _ = nav // silence warning
        }

        setupRuntime()
        buildRenderModel()
        setupCollectionView()

        GenerativeUILogger.shared.info(
            "Screen rendered",
            fields: ["screen_id": spec.id, "component_count": "\(spec.components.count)"]
        )
    }

    private func setupRuntime() {
        runtime.stateStore.reset(to: spec.state)
        runtime.eventBridge.onEvent = { [weak self] envelope in
            self?.onEvent(envelope)
        }
        renderContext = RenderContext(
            specId: spec.id,
            stateStore: runtime.stateStore,
            eventBridge: runtime.eventBridge
        )
    }

    private func buildRenderModel() {
        renderSections = RenderModelBuilder.build(from: spec)
    }

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 4
        layout.sectionInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.keyboardDismissMode = .interactive
        collectionView.alwaysBounceVertical = true

        collectionView.register(GUIComponentCell.self, forCellWithReuseIdentifier: Self.cellReuseId)
        collectionView.register(
            GUISectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: Self.headerReuseId
        )

        collectionView.dataSource = self
        collectionView.delegate = self

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

// MARK: - UICollectionViewDataSource

extension GenerativeScreenViewController: UICollectionViewDataSource {

    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        renderSections.count
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        renderSections[section].items.count
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: Self.cellReuseId,
            for: indexPath
        ) as! GUIComponentCell

        let sectionInset = (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset ?? .zero
        let availableWidth = collectionView.bounds.width - sectionInset.left - sectionInset.right

        let item = renderSections[indexPath.section].items[indexPath.item]
        if let definition = runtime.registry.componentDefinition(for: item.component.type) {
            let componentView = definition.makeView(component: item.component, context: renderContext)
            cell.configure(with: componentView, width: availableWidth)
        }

        return cell
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: Self.headerReuseId,
            for: indexPath
        ) as! GUISectionHeaderView

        let section = renderSections[indexPath.section]
        header.configure(title: section.title)
        return header
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension GenerativeScreenViewController: UICollectionViewDelegateFlowLayout {

    public func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let sectionInset = (collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset ?? .zero
        let availableWidth = collectionView.bounds.width - sectionInset.left - sectionInset.right

        let item = renderSections[indexPath.section].items[indexPath.item]
        guard let definition = runtime.registry.componentDefinition(for: item.component.type) else {
            return CGSize(width: availableWidth, height: 44)
        }

        // Constrain width to measure the component's fitting height.
        let componentView = definition.makeView(component: item.component, context: renderContext)
        componentView.translatesAutoresizingMaskIntoConstraints = false
        let widthConstraint = componentView.widthAnchor.constraint(equalToConstant: availableWidth)
        widthConstraint.isActive = true

        let fittingSize = componentView.systemLayoutSizeFitting(
            CGSize(width: availableWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        widthConstraint.isActive = false
        // Account for GUIComponentCell's 4pt top + 4pt bottom padding
        let cellPadding: CGFloat = 8
        return CGSize(width: availableWidth, height: max(fittingSize.height + cellPadding, 44))
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        let sectionModel = renderSections[section]
        if let title = sectionModel.title, !title.isEmpty {
            return CGSize(width: collectionView.bounds.width, height: 40)
        }
        return .zero
    }
}

// MARK: - Collection View Cell

/// A generic cell that hosts a single component view.
final class GUIComponentCell: UICollectionViewCell {

    private var hostedView: UIView?

    func configure(with view: UIView, width: CGFloat) {
        hostedView?.removeFromSuperview()
        hostedView = view

        view.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            contentView.widthAnchor.constraint(equalToConstant: width)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        hostedView?.removeFromSuperview()
        hostedView = nil
        for constraint in contentView.constraints where constraint.firstAttribute == .width {
            constraint.isActive = false
        }
    }
}

// MARK: - Section Header View

/// A supplementary view for section headers.
final class GUISectionHeaderView: UICollectionReusableView {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(title: String?) {
        titleLabel.text = title
    }
}
