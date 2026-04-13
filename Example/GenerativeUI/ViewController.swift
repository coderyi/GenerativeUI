import UIKit
import GenerativeUI

/// Example view controller demonstrating how to use the GenerativeUI framework.
/// Shows screen-level demos (push) and view-level demos (embed, sheet).
class ViewController: UIViewController {

    private let runtime = GenerativeUIRuntime()
    private let mockService = MockGenerativeUIService()

    /// Scroll view so the demo list is scrollable on smaller screens.
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.alwaysBounceVertical = true
        sv.keyboardDismissMode = .interactive
        return sv
    }()

    /// Container for header + grid.
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// 2-column grid for demo buttons.
    private let gridStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// Holds buttons temporarily before laying them out in rows.
    private var pendingButtons: [UIButton] = []

    /// Container for embedded view demos, placed at the bottom of the scroll content.
    private var embedContainer: UIView!

    /// Tracks the currently embedded view so we can remove it before adding a new one.
    private weak var currentEmbeddedView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "本地 JSON 演示"
        view.backgroundColor = .systemBackground

        setupUI()
    }

    private func setupUI() {
        // Description label
        let descLabel = UILabel()
        descLabel.text = "点击按钮体验不同的生成式 UI 场景"
        descLabel.font = UIFont.systemFont(ofSize: 14)
        descLabel.textColor = .secondaryLabel
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0
        stackView.addArrangedSubview(descLabel)

        // Collect buttons
        addDemoButton(title: "信息补充表单", keyword: "booking")
        addDemoButton(title: "精选酒店推荐", keyword: "__embed_hotel__")
        addDemoButton(title: "酒店列表", keyword: "__embed_list__")
        addDemoButton(title: "订单确认", keyword: "__embed_modal__")
        addDemoButton(title: "订单操作", keyword: "__sheet_quick__")
        addDemoButton(title: "天气卡片", keyword: "__embed_weather__")
        addDemoButton(title: "GitHub Trending", keyword: "__embed_github__")

        // Lay out buttons in 2-column rows
        layoutGridButtons()
        stackView.addArrangedSubview(gridStack)

        // Embed container at the bottom
        embedContainer = UIView()
        embedContainer.translatesAutoresizingMaskIntoConstraints = false
        embedContainer.backgroundColor = .secondarySystemBackground
        embedContainer.layer.cornerRadius = 12
        embedContainer.clipsToBounds = true
        embedContainer.isHidden = true

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        scrollView.addSubview(embedContainer)

        NSLayoutConstraint.activate([
            // ScrollView fills the safe area
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // StackView inside scroll content
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),

            // Embed container below the stack
            embedContainer.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 16),
            embedContainer.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            embedContainer.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            embedContainer.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    private func addDemoButton(title: String, keyword: String) {
        let button = UIButton(type: .system)

        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = .secondarySystemBackground
        config.baseForegroundColor = .label
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            return outgoing
        }
        button.configuration = config
        button.accessibilityIdentifier = keyword
        button.addTarget(self, action: #selector(demoButtonTapped(_:)), for: .touchUpInside)

        pendingButtons.append(button)
    }

    /// Arrange pending buttons into 2-column rows within gridStack.
    private func layoutGridButtons() {
        var index = 0
        while index < pendingButtons.count {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = 10
            rowStack.distribution = .fillEqually

            rowStack.addArrangedSubview(pendingButtons[index])
            index += 1

            if index < pendingButtons.count {
                rowStack.addArrangedSubview(pendingButtons[index])
                index += 1
            } else {
                // Odd button — add spacer to keep width consistent
                let spacer = UIView()
                rowStack.addArrangedSubview(spacer)
            }

            gridStack.addArrangedSubview(rowStack)
        }
        pendingButtons.removeAll()
    }

    // MARK: - Button Actions

    @objc private func demoButtonTapped(_ sender: UIButton) {
        let keyword = sender.accessibilityIdentifier ?? ""

        switch keyword {
        case "__embed_hotel__":
            embedView(keyword: "hotel")
        case "__embed_list__":
            embedView(keyword: "list")
        case "__embed_modal__":
            embedView(keyword: "modal")
        case "__sheet_quick__":
            presentSheet(keyword: "quick")
        case "__embed_weather__":
            embedView(keyword: "weather")
        case "__embed_github__":
            embedView(keyword: "github")
        default:
            // Screen demo via service pipeline (push)
            runtime.generateAndRender(
                service: mockService,
                message: keyword,
                onEvent: { [weak self] envelope in
                    self?.handleEvent(envelope)
                },
                completion: { [weak self] result in
                    switch result {
                    case .screen(let vc), .failure(let vc):
                        self?.navigationController?.pushViewController(vc, animated: true)
                    case .view(let renderer):
                        let vc = GenerativeViewContainerController(renderer: renderer)
                        self?.navigationController?.pushViewController(vc, animated: true)
                    }
                }
            )
        }
    }

    // MARK: - View Demos

    /// Loads a ViewSpec and embeds it at the bottom of the current page.
    private func embedView(keyword: String) {
        do {
            let doc = try mockService.loadDocument(keyword: keyword)
            let result = runtime.build(from: doc) { [weak self] envelope in
                self?.handleEvent(envelope)
            }
            if case .view(let renderer) = result {
                showEmbeddedView(renderer)
            }
        } catch {
            showAlert(title: "加载失败", message: error.localizedDescription)
        }
    }

    /// Loads a ViewSpec and presents it as a half-screen sheet.
    private func presentSheet(keyword: String) {
        do {
            let doc = try mockService.loadDocument(keyword: keyword)
            let result = runtime.build(from: doc) { [weak self] envelope in
                self?.handleEvent(envelope)
            }
            if case .view(let renderer) = result {
                let vc = GenerativeViewContainerController(renderer: renderer)
                vc.modalPresentationStyle = .pageSheet
                if let sheet = vc.sheetPresentationController {
                    sheet.detents = [.medium()]
                    sheet.prefersGrabberVisible = true
                }
                present(vc, animated: true)
            }
        } catch {
            showAlert(title: "加载失败", message: error.localizedDescription)
        }
    }

    /// Shows a rendered view in the embed container at the bottom.
    private func showEmbeddedView(_ renderer: GenerativeViewRenderer) {
        // Remove previous embedded view
        currentEmbeddedView?.removeFromSuperview()

        renderer.translatesAutoresizingMaskIntoConstraints = false
        embedContainer.addSubview(renderer)
        NSLayoutConstraint.activate([
            renderer.topAnchor.constraint(equalTo: embedContainer.topAnchor),
            renderer.leadingAnchor.constraint(equalTo: embedContainer.leadingAnchor),
            renderer.trailingAnchor.constraint(equalTo: embedContainer.trailingAnchor),
            renderer.bottomAnchor.constraint(equalTo: embedContainer.bottomAnchor)
        ])

        currentEmbeddedView = renderer
        embedContainer.isHidden = false
    }

    // MARK: - Event Handling

    private func handleEvent(_ envelope: InteractionEnvelope) {
        print("--- Event Received ---")
        print("Type: \(envelope.eventType.rawValue)")
        print("Spec: \(envelope.specId)")
        print("Component: \(envelope.componentId)")
        if let actionId = envelope.actionId {
            print("Action: \(actionId)")
        }
        if let binding = envelope.binding, let value = envelope.value {
            print("Binding: \(binding) = \(value)")
        }
        print("State: \(envelope.state)")
        print("----------------------")

        if envelope.eventType == .actionTriggered {
            if let actionId = envelope.actionId {
                switch actionId {
                case "booking.submit":
                    showAlert(title: "提交成功", message: "表单数据已收到\n状态: \(formatState(envelope.state))")
                case "quickAction.confirm":
                    let selected = envelope.state["selected"]?.stringValue ?? "未选择"
                    dismiss(animated: true) { [weak self] in
                        self?.showAlert(title: "操作确认", message: "您选择了: \(selected)")
                    }
                case "hotel.viewDetail":
                    showAlert(title: "查看详情", message: "正在跳转酒店详情页...")
                case "order.confirmPay":
                    showAlert(title: "支付确认", message: "正在发起支付...")
                default:
                    showAlert(title: "动作触发", message: "action: \(actionId)")
                }
            }
        }
    }

    private func formatState(_ state: [String: JSONValue]) -> String {
        state.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
