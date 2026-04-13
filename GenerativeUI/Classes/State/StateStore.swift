import Foundation

/// A render error that can be stored in the runtime state.
public struct RenderError: Equatable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

/// Page-level runtime state, managing bound values, submission status, and render errors.
public final class StateStore {

    /// The current state values keyed by binding name.
    public private(set) var currentValues: [String: JSONValue]

    /// Whether the screen is currently in a submitting state. Driven by the host app.
    public var isSubmitting: Bool = false {
        didSet {
            if oldValue != isSubmitting {
                onSubmittingChanged?(isSubmitting)
            }
        }
    }

    /// The current render error, if any.
    public var renderError: RenderError?

    /// Called when `isSubmitting` changes. The host can use this to update UI (e.g. loading indicators).
    public var onSubmittingChanged: ((Bool) -> Void)?

    /// Called when any state value changes.
    public var onValueChanged: ((String, JSONValue) -> Void)?

    /// Initializes the state store with initial values from `screen.state`.
    public init(initialValues: [String: JSONValue]) {
        self.currentValues = initialValues
    }

    /// Returns the current value for the given binding key.
    public func value(for key: String) -> JSONValue? {
        currentValues[key]
    }

    /// Updates the value for the given binding key.
    /// Only updates keys that were declared in the initial state.
    public func setValue(_ value: JSONValue, for key: String) {
        guard currentValues.keys.contains(key) else {
            GenerativeUILogger.shared.warning(
                "Attempted to set value for undeclared state key '\(key)'",
                fields: ["key": key]
            )
            return
        }
        currentValues[key] = value
        onValueChanged?(key, value)
    }

    /// Resets all values to the given initial state.
    public func reset(to initialValues: [String: JSONValue]) {
        currentValues = initialValues
        isSubmitting = false
        renderError = nil
    }
}
