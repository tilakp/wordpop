import Foundation

struct Phrase: Equatable {
    let phrase: String
    let definition: String
    let example: String?
}

/// Extracts the PHRASES and PHRASAL VERBS sub-entries from an entry's
/// XHTML markup. The flat text has no boundary between a phrase and its
/// definition ("run dry (of a well or river) cease to flow"), but the markup
/// wraps each in `class="subEntry"` with `class="l"` for the phrase,
/// `class="df"` for the definition and `class="ex"` for the example.
enum PhraseParser {
    static func phrases(in markup: String) -> [Phrase] {
        var result: [Phrase] = []
        for blockClass in ["t_phrases", "t_phrasalVerbs"] {
            guard let block = section(markup, blockClass: blockClass) else { continue }
            for chunk in block.components(separatedBy: "class=\"subEntry ").dropFirst() {
                guard let phrase = text(ofClass: "l", in: chunk), let definition = text(ofClass: "df", in: chunk) else { continue }
                result.append(Phrase(phrase: phrase, definition: definition, example: text(ofClass: "ex", in: chunk)))
            }
        }
        return result
    }

    private static func section(_ markup: String, blockClass: String) -> String? {
        guard let start = markup.range(of: "class=\"subEntryBlock x_xo0 \(blockClass)\"") else { return nil }
        let rest = markup[start.upperBound...]
        let end = rest.range(of: "class=\"subEntryBlock")?.lowerBound ?? rest.endIndex
        return String(rest[..<end])
    }

    /// Text content of the first element whose class attribute starts with
    /// `cssClass`, with nested tags stripped and entities decoded.
    private static func text(ofClass cssClass: String, in chunk: String) -> String? {
        guard let attribute = chunk.range(of: "class=\"\(cssClass)\"") ?? chunk.range(of: "class=\"\(cssClass) "),
              let open = chunk.range(of: ">", range: attribute.upperBound..<chunk.endIndex) else { return nil }
        var depth = 1
        var text = ""
        var index = open.upperBound
        while index < chunk.endIndex, depth > 0 {
            if chunk[index] == "<" {
                guard let close = chunk.range(of: ">", range: index..<chunk.endIndex) else { break }
                let tag = chunk[index..<close.upperBound]
                if tag.hasPrefix("</") { depth -= 1 } else if !tag.hasSuffix("/>") { depth += 1 }
                index = close.upperBound
            } else {
                text.append(chunk[index])
                index = chunk.index(after: index)
            }
        }
        let cleaned = decodeEntities(text).trimmingCharacters(in: CharacterSet(charactersIn: " .:"))
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func decodeEntities(_ text: String) -> String {
        text.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
    }
}
