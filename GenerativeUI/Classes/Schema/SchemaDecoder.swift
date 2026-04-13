import Foundation

/// Responsible for decoding raw JSON data into GenerativeUI documents.
public enum SchemaDecoder {

    /// Decodes JSON data into a ``GenerativeUIDocument``.
    ///
    /// - Parameter data: Raw JSON data.
    /// - Returns: A decoded ``GenerativeUIDocument``.
    /// - Throws: ``GenerativeUIError/decodingFailed(_:)`` if the JSON is invalid.
    public static func decodeDocument(from data: Data) throws -> GenerativeUIDocument {
        do {
            return try JSONDecoder().decode(GenerativeUIDocument.self, from: data)
        } catch let error as GenerativeUIError {
            throw error
        } catch {
            throw GenerativeUIError.decodingFailed(
                ErrorDescriptor(code: "DECODE_ERROR", message: error.localizedDescription)
            )
        }
    }

    /// Decodes a JSON string into a ``GenerativeUIDocument``.
    public static func decodeDocument(from jsonString: String) throws -> GenerativeUIDocument {
        guard let data = jsonString.data(using: .utf8) else {
            throw GenerativeUIError.decodingFailed(
                ErrorDescriptor(code: "INVALID_UTF8", message: "Input string is not valid UTF-8")
            )
        }
        return try decodeDocument(from: data)
    }
}
