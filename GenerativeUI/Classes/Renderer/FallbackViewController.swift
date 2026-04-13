import UIKit

/// A standardized fallback view displayed when screen generation, decoding, validation, or rendering fails.
/// Does not expose raw model output. Shows a generic message with an optional error code in debug mode.
public final class FallbackViewController: UIViewController {

    private let errorInfo: GenerativeUIError?

    /// Creates a fallback view controller.
    /// - Parameter error: The error that caused the fallback. Used for debug display only.
    public init(error: GenerativeUIError? = nil) {
        self.errorInfo = error
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Icon
        let iconLabel = UILabel()
        iconLabel.text = "!"
        iconLabel.font = UIFont.systemFont(ofSize: 48, weight: .bold)
        iconLabel.textColor = .systemOrange
        iconLabel.textAlignment = .center
        stack.addArrangedSubview(iconLabel)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Unable to Display Content"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        stack.addArrangedSubview(titleLabel)

        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Please try again later"
        subtitleLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        stack.addArrangedSubview(subtitleLabel)

        // Debug info (only in DEBUG builds)
        #if DEBUG
        if let error = errorInfo {
            let debugLabel = UILabel()
            debugLabel.text = debugDescription(for: error)
            debugLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            debugLabel.textColor = .tertiaryLabel
            debugLabel.textAlignment = .center
            debugLabel.numberOfLines = 0
            stack.addArrangedSubview(debugLabel)
        }
        #endif

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])
    }

    private func debugDescription(for error: GenerativeUIError) -> String {
        switch error {
        case .generationFailed(let desc):
            return "Generation: \(desc.code)"
        case .extractionFailed(let desc):
            return "Extraction: \(desc.code)"
        case .decodingFailed(let desc):
            return "Decoding: \(desc.code)"
        case .validationFailed(let issues):
            return "Validation: \(issues.map { $0.code.rawValue }.joined(separator: ", "))"
        case .renderingFailed(let desc):
            return "Rendering: \(desc.code)"
        }
    }
}
