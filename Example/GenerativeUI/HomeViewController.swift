import UIKit

/// The app's landing page with two entry cards:
/// 1. Local JSON demos — navigates to the existing ViewController
/// 2. Chat UI generation — navigates to ChatViewController
final class HomeViewController: UIViewController {

    // MARK: - UI Elements

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "GenerativeUI"
        view.backgroundColor = .systemBackground
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        // Entry card 1: Local JSON
        let jsonCard = makeEntryCard(
            icon: "doc.text",
            title: "本地 JSON 演示",
            subtitle: "预置 JSON 场景演示，覆盖多种组件与布局",
            action: #selector(openLocalDemos)
        )
        stackView.addArrangedSubview(jsonCard)

        // Entry card 2: Chat
        let chatCard = makeEntryCard(
            icon: "bubble.left.and.bubble.right",
            title: "Chat 生成 UI",
            subtitle: "用自然语言描述界面，LLM 实时生成交互式卡片",
            action: #selector(openChat)
        )
        stackView.addArrangedSubview(chatCard)

        // Layout
        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
    }

    /// Creates a large tappable entry card with icon, title, and subtitle.
    private func makeEntryCard(icon: String, title: String, subtitle: String, action: Selector) -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 16
        card.clipsToBounds = true

        // Icon
        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = .systemBlue
        iconView.contentMode = .scaleAspectFit

        // Title
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .label

        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        // Text stack
        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 4

        // Content stack (icon + text)
        let contentStack = UIStackView(arrangedSubviews: [iconView, textStack])
        contentStack.axis = .horizontal
        contentStack.spacing = 16
        contentStack.alignment = .center
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(contentStack)

        // Chevron
        let chevron = UIImageView()
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.image = UIImage(systemName: "chevron.right")
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        card.addSubview(chevron)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 36),
            iconView.heightAnchor.constraint(equalToConstant: 36),

            contentStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            contentStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -12),

            chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),
        ])

        // Tap gesture
        let tap = UITapGestureRecognizer(target: self, action: action)
        card.addGestureRecognizer(tap)
        card.isUserInteractionEnabled = true

        return card
    }

    // MARK: - Navigation

    @objc private func openLocalDemos() {
        let vc = ViewController()
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func openChat() {
        let vc = ChatViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
}
