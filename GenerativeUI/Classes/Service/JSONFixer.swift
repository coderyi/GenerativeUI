import Foundation

/// Repairs common JSON errors produced by LLMs.
///
/// LLMs frequently generate almost-valid JSON with issues like smart quotes,
/// trailing commas, or unescaped control characters.  ``JSONFixer`` applies a
/// pipeline of lightweight string transforms to salvage the JSON before decoding.
///
/// The fixer follows a **try-first** strategy:
/// it only runs the repair pipeline when `JSONSerialization` rejects the input.
///
/// ## Fix Pipeline
/// 1. Normalize smart (curly) quotes → straight quotes
/// 2. Remove trailing commas before `}` or `]`
/// 3. Escape unescaped control characters inside string values
public struct JSONFixer: Sendable {

    /// Shared default instance.
    public static let `default` = JSONFixer()

    private static let trailingCommaRegex = try! NSRegularExpression(
        pattern: ",\\s*(?=[\\]\\}])"
    )

    public init() {}

    /// Attempts to fix common LLM JSON errors.
    ///
    /// If the input is already valid JSON, it is returned unchanged.
    /// Otherwise the repair pipeline runs and the result is returned
    /// regardless of whether it is now valid (the caller should still
    /// attempt decoding and handle errors).
    ///
    /// - Parameter jsonString: A possibly-broken JSON string.
    /// - Returns: The original string if valid, or a repaired version.
    public func fix(_ jsonString: String) -> String {
        // Fast path: already valid → return as-is (avoid unnecessary mutation).
        if isValidJSON(jsonString) {
            return jsonString
        }

        // Apply fixes in order.
        var result = jsonString
        result = normalizeSmartQuotes(result)
        result = removeTrailingCommas(result)
        result = escapeControlCharacters(result)

        return result
    }

    // MARK: - Validation

    private func isValidJSON(_ string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    // MARK: - Fix Operations

    /// Replaces Unicode smart/curly quotes with ASCII straight quotes.
    ///
    /// LLMs trained on web text sometimes emit:
    /// - U+201C / U+201D (left/right double quotation marks)
    /// - U+2018 / U+2019 (left/right single quotation marks)
    /// - U+00AB / U+00BB (guillemets)
    private func normalizeSmartQuotes(_ text: String) -> String {
        var s = text
        // Double quotes
        s = s.replacingOccurrences(of: "\u{201C}", with: "\"")  // "
        s = s.replacingOccurrences(of: "\u{201D}", with: "\"")  // "
        // Curly single quotes → straight single quotes
        s = s.replacingOccurrences(of: "\u{2018}", with: "'")   // '
        s = s.replacingOccurrences(of: "\u{2019}", with: "'")   // '
        // Guillemets (rare but seen in some multilingual outputs)
        s = s.replacingOccurrences(of: "\u{00AB}", with: "\"")  // «
        s = s.replacingOccurrences(of: "\u{00BB}", with: "\"")  // »
        return s
    }

    /// Removes trailing commas before `}` or `]`.
    ///
    /// Example: `{"a": 1, "b": 2,}` → `{"a": 1, "b": 2}`
    private func removeTrailingCommas(_ text: String) -> String {
        let range = NSRange(text.startIndex..., in: text)
        return Self.trailingCommaRegex.stringByReplacingMatches(
            in: text, range: range, withTemplate: ""
        )
    }

    /// Escapes unescaped control characters (tabs, newlines) inside JSON string values.
    ///
    /// LLMs occasionally produce literal tab or newline characters within
    /// JSON string values instead of the escaped `\t` / `\n` sequences.
    private func escapeControlCharacters(_ text: String) -> String {
        var result: [Character] = []
        var inString = false
        var escaped = false

        for ch in text {
            if escaped {
                result.append(ch)
                escaped = false
                continue
            }

            if ch == "\\" && inString {
                result.append(ch)
                escaped = true
                continue
            }

            if ch == "\"" {
                inString.toggle()
                result.append(ch)
                continue
            }

            if inString {
                switch ch {
                case "\n":
                    result.append(contentsOf: "\\n")
                    continue
                case "\r":
                    result.append(contentsOf: "\\r")
                    continue
                case "\t":
                    result.append(contentsOf: "\\t")
                    continue
                default:
                    break
                }
            }

            result.append(ch)
        }

        return String(result)
    }
}
