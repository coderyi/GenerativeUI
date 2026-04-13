import UIKit

/// The central runtime object that ties together all GenerativeUI modules.
/// The host app creates one instance and uses it to validate, render, and handle events.
public final class GenerativeUIRuntime {

    /// The component and action registry.
    public let registry: ComponentRegistry

    /// The validator for checking specs.
    public let validator: GenerativeUIDocumentValidator

    /// The page-level state store.
    public let stateStore: StateStore

    /// The event bridge for dispatching interaction events.
    public let eventBridge: EventBridge

    private let logger = GenerativeUILogger.shared

    /// Creates a runtime with the default MVP registry.
    public convenience init() {
        self.init(registry: ComponentRegistry.makeDefault())
    }

    /// Creates a runtime with a custom registry.
    public init(registry: ComponentRegistry) {
        self.registry = registry
        self.validator = GenerativeUIDocumentValidator(registry: registry)
        self.stateStore = StateStore(initialValues: [:])
        self.eventBridge = EventBridge(registry: registry)
    }

    // MARK: - Unified Build (0.1)

    /// The render result from the unified build pipeline.
    public enum RenderResult {
        /// A full-page screen, rendered as a UIViewController.
        case screen(UIViewController)
        /// A block-level view, rendered as a UIView.
        case view(GenerativeViewRenderer)
        /// Decode or validation failed. The host should display this fallback ViewController.
        case failure(UIViewController)
    }

    /// Builds from raw JSON data (schema 0.1).
    public func build(
        from data: Data,
        onEvent: @escaping (InteractionEnvelope) -> Void
    ) -> RenderResult {
        let document: GenerativeUIDocument
        do {
            document = try SchemaDecoder.decodeDocument(from: data)
        } catch let error as GenerativeUIError {
            logger.error("Decoding failed", fields: ["error": "\(error)"])
            return .failure(FallbackViewController(error: error))
        } catch {
            let guiError = GenerativeUIError.decodingFailed(
                ErrorDescriptor(code: "UNKNOWN_DECODE", message: error.localizedDescription)
            )
            return .failure(FallbackViewController(error: guiError))
        }

        return build(from: document, onEvent: onEvent)
    }

    /// Builds from an already-decoded `GenerativeUIDocument`.
    public func build(
        from document: GenerativeUIDocument,
        onEvent: @escaping (InteractionEnvelope) -> Void
    ) -> RenderResult {
        // Validate
        let issues = validator.validate(document)
        if !issues.isEmpty {
            let error = GenerativeUIError.validationFailed(issues)
            let id: String
            switch document.content {
            case .screen(let s): id = s.id
            case .view(let v): id = v.id
            }
            logger.error("Validation failed", fields: [
                "spec_id": id,
                "issue_count": "\(issues.count)",
                "first_issue": issues.first?.code.rawValue ?? "-"
            ])
            return .failure(FallbackViewController(error: error))
        }

        // Render
        switch document.content {
        case .screen(let screen):
            logger.info("Rendering screen", fields: ["screen_id": screen.id])
            let vc = GenerativeScreenViewController(spec: screen, runtime: self, onEvent: onEvent)
            return .screen(vc)

        case .view(let viewSpec):
            logger.info("Rendering view", fields: ["view_id": viewSpec.id])
            let renderer = GenerativeViewRenderer()
            renderer.onEvent = onEvent
            renderer.render(spec: viewSpec, runtime: self)
            return .view(renderer)
        }
    }

    /// Convenience: builds from a JSON string (schema 0.1).
    public func build(
        from jsonString: String,
        onEvent: @escaping (InteractionEnvelope) -> Void
    ) -> RenderResult {
        guard let data = jsonString.data(using: .utf8) else {
            let error = GenerativeUIError.decodingFailed(
                ErrorDescriptor(code: "INVALID_UTF8", message: "Input string is not valid UTF-8")
            )
            return .failure(FallbackViewController(error: error))
        }
        return build(from: data, onEvent: onEvent)
    }

    // MARK: - Service Pipeline

    /// Generates and renders UI using a ``GenerativeUIService``.
    /// Supports schema 0.1 (both screen and view content).
    /// Delivers the result via completion on the main queue.
    public func generateAndRender(
        service: GenerativeUIService,
        message: String,
        onEvent: @escaping (InteractionEnvelope) -> Void,
        completion: @escaping (RenderResult) -> Void
    ) {
        logger.info("Generation started", fields: ["message": message])

        Task {
            do {
                let document = try await service.generate(message: message)
                let result = self.build(from: document, onEvent: onEvent)
                DispatchQueue.main.async { completion(result) }
            } catch {
                self.logger.error("Generation failed", fields: ["error": error.localizedDescription])
                let guiError = (error as? GenerativeUIError) ?? GenerativeUIError.generationFailed(
                    ErrorDescriptor(code: "GENERATION_ERROR", message: error.localizedDescription)
                )
                DispatchQueue.main.async {
                    completion(.failure(FallbackViewController(error: guiError)))
                }
            }
        }
    }

}
