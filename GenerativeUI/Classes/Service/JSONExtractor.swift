import Foundation

/// Extracts JSON from raw LLM response text.
///
/// LLMs often wrap JSON in markdown code fences, mix it with conversational
/// text, or use custom delimiter tags.  ``JSONExtractor`` tries multiple
/// strategies in priority order and returns the first match.
///
/// Strategy priority:
/// 1. Custom delimiter tags: `<generativeui-json>…</generativeui-json>`
/// 2. Markdown code blocks: ` ```json … ``` ` or ` ``` … ``` `
/// 3. Outermost brace matching: first `{` to last `}`
/// 4. Return original text (let the decoder produce a clear error)
public struct JSONExtractor: Sendable {

    /// Shared default instance.
    public static let `default` = JSONExtractor()

    /// The opening tag for custom-delimited JSON blocks.
    public let openTag: String

    /// The closing tag for custom-delimited JSON blocks.
    public let closeTag: String

    /// Creates an extractor with optional custom delimiter tags.
    ///
    /// - Parameters:
    ///   - openTag:  Opening delimiter (default `<generativeui-json>`).
    ///   - closeTag: Closing delimiter (default `</generativeui-json>`).
    public init(
        openTag: String = "<generativeui-json>",
        closeTag: String = "</generativeui-json>"
    ) {
        self.openTag = openTag
        self.closeTag = closeTag
    }

    /// Extracts a JSON string from the given LLM response text.
    ///
    /// - Parameter text: Raw text from the LLM, possibly containing JSON.
    /// - Returns: The extracted JSON string, or the original text if no JSON was found.
    public func extract(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Custom delimiter tags
        if let result = extractFromTags(trimmed) {
            return result
        }

        // 2. Markdown code blocks
        if let result = extractFromCodeBlock(trimmed) {
            return result
        }

        // 3. Outermost brace matching
        if let result = extractFromBraces(trimmed) {
            return result
        }

        // 4. Return as-is
        return trimmed
    }

    // MARK: - Static Regex

    private static let codeBlockRegex = try! NSRegularExpression(
        pattern: "```(?:json)?\\s*\\n?([\\s\\S]*?)\\n?```"
    )

    // MARK: - Private Strategies

    /// Extracts content between custom delimiter tags.
    private func extractFromTags(_ text: String) -> String? {
        guard let openRange = text.range(of: openTag),
              let closeRange = text.range(of: closeTag, range: openRange.upperBound..<text.endIndex)
        else { return nil }

        let content = String(text[openRange.upperBound..<closeRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return content.isEmpty ? nil : content
    }

    /// Extracts content from ` ```json … ``` ` or ` ``` … ``` ` blocks.
    private func extractFromCodeBlock(_ text: String) -> String? {
        guard let match = Self.codeBlockRegex.firstMatch(
                  in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text)
        else { return nil }

        let content = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return content.isEmpty ? nil : content
    }

    /// Extracts JSON by matching the outermost `{` … `}` pair using brace counting.
    ///
    /// This is more reliable than `firstIndex(of: "{")` / `lastIndex(of: "}")`
    /// because it ignores braces inside string literals.
    private func extractFromBraces(_ text: String) -> String? {
        guard let startIdx = text.firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var escaped = false
        var endIdx: String.Index?

        for idx in text.indices[startIdx...] {
            let ch = text[idx]

            if escaped {
                escaped = false
                continue
            }

            if ch == "\\" && inString {
                escaped = true
                continue
            }

            if ch == "\"" {
                inString.toggle()
                continue
            }

            if inString { continue }

            if ch == "{" {
                depth += 1
            } else if ch == "}" {
                depth -= 1
                if depth == 0 {
                    endIdx = idx
                    break
                }
            }
        }

        guard let end = endIdx else { return nil }
        return String(text[startIdx...end])
    }
}
