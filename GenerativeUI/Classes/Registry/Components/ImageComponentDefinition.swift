import UIKit

/// Definition for the `image` component type.
/// Renders a remote image with async loading, placeholder, and failure fallback.
internal final class ImageComponentDefinition: ComponentDefinition {
    let type: ComponentType = .image
    let category: ComponentCategory = .display
    let allowsChildren = false
    let supportedEvents: Set<EventType> = []
    let requiredProps: Set<String> = ["url"]

    func validate(props: [String: JSONValue]) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []

        if let url = props["url"]?.stringValue {
            if url.trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append(ValidationIssue(
                    code: .invalidProps,
                    path: "props.url",
                    message: "image url must be a non-empty string"
                ))
            }
        } else {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.url",
                message: "image requires a string 'url' prop"
            ))
        }

        if let height = props["height"], height.doubleValue ?? -1 <= 0 {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.height",
                message: "image height must be > 0"
            ))
        }

        if let cornerRadius = props["cornerRadius"], cornerRadius.doubleValue ?? -1 < 0 {
            issues.append(ValidationIssue(
                code: .invalidProps,
                path: "props.cornerRadius",
                message: "image cornerRadius must be >= 0"
            ))
        }

        return issues
    }

    func makeView(component: ComponentSpec, context: RenderContext) -> UIView {
        let height = component.props["height"]?.doubleValue ?? 180
        let cornerRadius = component.props["cornerRadius"]?.doubleValue ?? 0
        let contentMode = Self.mapContentMode(component.props["contentMode"]?.stringValue)

        let imageView = UIImageView()
        imageView.contentMode = contentMode
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = cornerRadius
        imageView.backgroundColor = UIColor.systemGray5
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.heightAnchor.constraint(equalToConstant: height).isActive = true

        if let label = component.props["accessibilityLabel"]?.stringValue {
            imageView.accessibilityLabel = label
            imageView.isAccessibilityElement = true
        }

        // Async image loading using native URLSession
        if let urlString = component.props["url"]?.stringValue,
           let url = URL(string: urlString) {
            Self.loadImage(from: url, into: imageView)
        } else {
            Self.applyPlaceholder(to: imageView, message: "Invalid URL")
        }

        return imageView
    }

    // MARK: - Helpers

    private static func loadImage(from url: URL, into imageView: UIImageView) {
        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async { [weak imageView] in
                guard let imageView = imageView else { return }
                if let data = data, let image = UIImage(data: data) {
                    imageView.image = image
                    imageView.backgroundColor = .clear
                    removePlaceholderLabel(from: imageView)
                } else {
                    let message = error?.localizedDescription ?? "Load failed"
                    applyPlaceholder(to: imageView, message: message)
                }
            }
        }
        task.resume()
    }

    private static let placeholderTag = 9001

    private static func applyPlaceholder(to imageView: UIImageView, message: String) {
        imageView.backgroundColor = UIColor.systemGray5

        // Reuse existing placeholder label if present
        if let existing = imageView.viewWithTag(placeholderTag) as? UILabel {
            existing.text = message
            return
        }

        let label = UILabel()
        label.tag = placeholderTag
        label.text = message
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        imageView.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: imageView.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: imageView.trailingAnchor, constant: -8)
        ])
    }

    private static func removePlaceholderLabel(from imageView: UIImageView) {
        imageView.viewWithTag(placeholderTag)?.removeFromSuperview()
    }

    private static func mapContentMode(_ value: String?) -> UIView.ContentMode {
        switch value {
        case "scaleAspectFill": return .scaleAspectFill
        case "scaleToFill":    return .scaleToFill
        default:               return .scaleAspectFit
        }
    }

}
