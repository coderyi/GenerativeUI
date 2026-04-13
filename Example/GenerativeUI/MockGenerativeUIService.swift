import Foundation
import GenerativeUI

/// A mock implementation of ``GenerativeUIService`` for UI development and testing.
/// Loads specs from local JSON files, exercising the full decode pipeline.
///
/// Conforms to ``GenerativeUIService`` so it can be used interchangeably with
/// ``GenerativeUILLMService`` wherever the protocol is expected.
final class MockGenerativeUIService: GenerativeUIService {

    /// The default JSON file name when no keyword matches.
    private let defaultFile = "view_booking_form"

    /// Maps keywords to JSON file names (without extension).
    private let keywordToFile: [String: String] = [
        "booking": "view_booking_form",
        "hotel": "view_hotel_featured",
        "quick": "view_order_actions",
        "order": "view_order_actions",
        "media": "view_hotel_featured",
        "featured": "view_hotel_featured",
        "modal": "view_order_confirm",
        "confirm": "view_order_confirm",
        "list": "view_hotel_list",
        "weather": "view_weather",
        "天气": "view_weather",
        "github": "view_github_trending",
        "trending": "view_github_trending",
    ]

    // MARK: - GenerativeUIService

    func generate(message: String) async throws -> GenerativeUIDocument {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000)
        return try loadDocument(keyword: message)
    }

    // MARK: - Synchronous Loading (for embed/sheet demos that don't need async)

    /// Loads a ``GenerativeUIDocument`` by keyword.
    /// Tries exact match first, then substring match, then falls back to default.
    func loadDocument(keyword: String) throws -> GenerativeUIDocument {
        let lowered = keyword.lowercased()

        // Exact match
        if let file = keywordToFile[lowered] {
            return try loadJSON(named: file)
        }

        // Substring match
        for (key, file) in keywordToFile {
            if lowered.contains(key) {
                return try loadJSON(named: file)
            }
        }

        return try loadJSON(named: defaultFile)
    }

    // MARK: - Private

    private func loadJSON(named fileName: String) throws -> GenerativeUIDocument {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            throw GenerativeUIError.generationFailed(
                ErrorDescriptor(code: "FILE_NOT_FOUND", message: "Mock JSON file '\(fileName).json' not found in bundle")
            )
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw GenerativeUIError.generationFailed(
                ErrorDescriptor(code: "FILE_READ_ERROR", message: error.localizedDescription)
            )
        }

        return try SchemaDecoder.decodeDocument(from: data)
    }
}
