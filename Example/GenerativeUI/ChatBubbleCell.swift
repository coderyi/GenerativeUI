import UIKit
import GenerativeUI

/// A table view cell that displays a single chat message as a bubble.
/// Supports user text (right-aligned), assistant text (left-aligned),
/// assistant ViewSpec card (left-aligned), and loading indicator.
final class ChatBubbleCell: UITableViewCell {

    static let reuseIdentifier = "ChatBubbleCell"

    // MARK: - UI Elements

    private let bubbleContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 12
        v.clipsToBounds = true
        return v
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16)
        return label
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    /// Bottom constraint for messageLabel — deactivated when renderer is shown.
    private var labelBottomConstraint: NSLayoutConstraint!
    /// Minimum height for loading bubble — created once, toggled on/off.
    private var loadingHeightConstraint: NSLayoutConstraint!
    /// Minimum width for loading bubble — created once, toggled on/off.
    private var loadingWidthConstraint: NSLayoutConstraint!

    /// Tracks the currently embedded ViewSpec renderer so we can remove it on reuse.
    private var currentRenderer: GenerativeViewRenderer?

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Setup

    private func setupViews() {
        contentView.addSubview(bubbleContainer)
        bubbleContainer.addSubview(messageLabel)
        bubbleContainer.addSubview(loadingIndicator)

        // Bubble constraints — max width 80% of cell
        let maxWidth = bubbleContainer.widthAnchor.constraint(
            lessThanOrEqualTo: contentView.widthAnchor,
            multiplier: 0.8
        )
        maxWidth.priority = .required

        leadingConstraint = bubbleContainer.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor, constant: 12
        )
        trailingConstraint = bubbleContainer.trailingAnchor.constraint(
            equalTo: contentView.trailingAnchor, constant: -12
        )

        labelBottomConstraint = messageLabel.bottomAnchor.constraint(
            equalTo: bubbleContainer.bottomAnchor, constant: -10
        )

        // Loading size constraints — created once, toggled as needed
        loadingHeightConstraint = bubbleContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        loadingHeightConstraint.priority = .defaultHigh
        loadingWidthConstraint = bubbleContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 60)
        loadingWidthConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            bubbleContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            maxWidth,

            // Label inside bubble
            messageLabel.topAnchor.constraint(equalTo: bubbleContainer.topAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleContainer.leadingAnchor, constant: 14),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleContainer.trailingAnchor, constant: -14),
            labelBottomConstraint,

            // Loading indicator centered in bubble
            loadingIndicator.centerXAnchor.constraint(equalTo: bubbleContainer.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: bubbleContainer.centerYAnchor),
        ])
    }

    // MARK: - Configuration

    func configure(with message: ChatMessage) {
        // Clean up previous renderer
        removeRenderer()
        // Reset loading constraints
        loadingHeightConstraint.isActive = false
        loadingWidthConstraint.isActive = false

        switch message.content {
        case .text(let text):
            configureTextBubble(text: text, role: message.role)

        case .viewSpec(let renderer):
            configureViewSpecBubble(renderer: renderer)

        case .loading:
            configureLoadingBubble()
        }
    }

    // MARK: - Bubble Variants

    private func configureTextBubble(text: String, role: ChatMessage.Role) {
        messageLabel.text = text
        messageLabel.isHidden = false
        labelBottomConstraint.isActive = true
        loadingIndicator.stopAnimating()

        switch role {
        case .user:
            applyUserStyle()
        case .assistant:
            applyAssistantStyle()
        }
    }

    private func configureViewSpecBubble(renderer: GenerativeViewRenderer) {
        messageLabel.isHidden = true
        labelBottomConstraint.isActive = false
        loadingIndicator.stopAnimating()
        applyAssistantStyle()

        // Embed the renderer inside the bubble
        renderer.translatesAutoresizingMaskIntoConstraints = false
        bubbleContainer.addSubview(renderer)
        NSLayoutConstraint.activate([
            renderer.topAnchor.constraint(equalTo: bubbleContainer.topAnchor, constant: 4),
            renderer.leadingAnchor.constraint(equalTo: bubbleContainer.leadingAnchor, constant: 4),
            renderer.trailingAnchor.constraint(equalTo: bubbleContainer.trailingAnchor, constant: -4),
            renderer.bottomAnchor.constraint(equalTo: bubbleContainer.bottomAnchor, constant: -4),
        ])
        currentRenderer = renderer
    }

    private func configureLoadingBubble() {
        messageLabel.isHidden = true
        labelBottomConstraint.isActive = false
        loadingIndicator.startAnimating()
        applyAssistantStyle()

        loadingHeightConstraint.isActive = true
        loadingWidthConstraint.isActive = true
    }

    // MARK: - Styling

    private func applyUserStyle() {
        bubbleContainer.backgroundColor = .systemBlue
        messageLabel.textColor = .white

        leadingConstraint.isActive = false
        trailingConstraint.isActive = true
    }

    private func applyAssistantStyle() {
        bubbleContainer.backgroundColor = .secondarySystemBackground
        messageLabel.textColor = .label

        trailingConstraint.isActive = false
        leadingConstraint.isActive = true
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        removeRenderer()
        messageLabel.isHidden = false
        messageLabel.text = nil
        labelBottomConstraint.isActive = true
        loadingIndicator.stopAnimating()
        loadingHeightConstraint.isActive = false
        loadingWidthConstraint.isActive = false
        leadingConstraint.isActive = false
        trailingConstraint.isActive = false
    }

    private func removeRenderer() {
        currentRenderer?.removeFromSuperview()
        currentRenderer = nil
    }
}
