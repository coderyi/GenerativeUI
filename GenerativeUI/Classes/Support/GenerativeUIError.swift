import Foundation

/// Unified error domain for the GenerativeUI framework.
public enum GenerativeUIError: Error {
    /// The LLM adapter failed to generate a screen.
    case generationFailed(ErrorDescriptor)
    /// No valid JSON could be extracted from the LLM response text.
    case extractionFailed(ErrorDescriptor)
    /// The JSON response could not be decoded into a GenerativeUIDocument.
    case decodingFailed(ErrorDescriptor)
    /// The decoded ScreenSpec failed validation.
    case validationFailed([ValidationIssue])
    /// The rendering process encountered an error.
    case renderingFailed(ErrorDescriptor)
}

/// A structured error descriptor with a machine-readable code and human-readable message.
public struct ErrorDescriptor: Equatable, Encodable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

/// A structured validation issue with a code, JSON path, and message.
public struct ValidationIssue: Equatable, Encodable {
    public let code: ValidationIssueCode
    public let path: String
    public let message: String

    public init(code: ValidationIssueCode, path: String, message: String) {
        self.code = code
        self.path = path
        self.message = message
    }
}

/// Machine-readable validation issue codes.
public enum ValidationIssueCode: String, Encodable {
    case unsupportedSchemaVersion
    case missingRequiredField
    case duplicateComponentID
    case unsupportedComponentType
    case invalidChildrenUsage
    case invalidBinding
    case invalidAction
    case invalidProps
}
