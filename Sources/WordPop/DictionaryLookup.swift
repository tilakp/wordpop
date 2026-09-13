import CoreServices
import Foundation

struct DefinitionItem {
    let number: Int?
    let text: String
    let example: String?
    let isSubItem: Bool
}

struct WordEntry {
    let word: String
    let partOfSpeech: String?
    let pronunciation: String?
    let items: [DefinitionItem]
    let synonyms: [String]
    let antonyms: [String]
    let rhymes: [String]
    let origin: String?
    let found: Bool

    static let empty = WordEntry(
        word: "", partOfSpeech: nil, pronunciation: nil, items: [],
        synonyms: [], antonyms: [], rhymes: [], origin: nil, found: false
    )

    func replacingSynonyms(_ newSynonyms: [String]) -> WordEntry {
        WordEntry(
            word: word, partOfSpeech: partOfSpeech, pronunciation: pronunciation, items: items,
            synonyms: newSynonyms, antonyms: antonyms, rhymes: rhymes, origin: origin, found: found
        )
    }
}

/// Looks up a word using macOS's built-in Dictionary Services (the same data
/// that powers Dictionary.app / the trackpad "Look Up" popover) for
/// definitions, examples and pronunciation. Fully offline, in-memory, no
/// network calls. Synonyms come from a bundled dataset (see SynonymStore)
/// since Dictionary Services has no public API for its separate Thesaurus.
enum DictionaryLookup {
    static func lookup(_ rawWord: String) -> WordEntry {
        let word = rawWord.trimmingCharacters(in: .whitespacesAndNewlines)

        let rhymes = RhymeStore.rhymes(for: word)

        guard let entryText = rawEntryText(for: word) else {
            let synonyms = SynonymStore.synonyms(for: word, partOfSpeech: nil)
            let antonyms = AntonymStore.antonyms(for: word, partOfSpeech: nil)
            return WordEntry(
                word: word, partOfSpeech: nil, pronunciation: nil, items: [],
                synonyms: synonyms, antonyms: antonyms, rhymes: rhymes, origin: nil,
                found: !synonyms.isEmpty || !antonyms.isEmpty || !rhymes.isEmpty
            )
        }

        let pronunciation = extractPronunciation(from: entryText)
        let partOfSpeech = extractPartOfSpeech(from: entryText)
        let items = parseItems(entryText)
        let origin = extractOrigin(from: entryText)
        let synonyms = SynonymStore.synonyms(for: word, partOfSpeech: partOfSpeech)
        let antonyms = AntonymStore.antonyms(for: word, partOfSpeech: partOfSpeech)

        return WordEntry(
            word: word,
            partOfSpeech: partOfSpeech,
            pronunciation: pronunciation,
            items: items,
            synonyms: synonyms,
            antonyms: antonyms,
            rhymes: rhymes,
            origin: origin,
            found: true
        )
    }

    private static func rawEntryText(for word: String) -> String? {
        let cfWord = word as CFString
        let termRange = DCSGetTermRangeInString(nil, cfWord, 0)

        let rangeToUse: CFRange
        if termRange.location == kCFNotFound {
            rangeToUse = CFRange(location: 0, length: CFStringGetLength(cfWord))
        } else {
            rangeToUse = termRange
        }

        guard let definition = DCSCopyTextDefinition(nil, cfWord, rangeToUse) else { return nil }
        return definition.takeRetainedValue() as String
    }

    private static func extractPronunciation(from text: String) -> String? {
        let parts = text.components(separatedBy: "|")
        guard parts.count >= 3 else { return nil }
        let candidate = parts[1].trimmingCharacters(in: .whitespaces)
        return candidate.isEmpty ? nil : candidate
    }

    private static let partOfSpeechWords = "noun|verb|adjective|adverb|pronoun|preposition|conjunction|interjection|exclamation|determiner|predeterminer|abbreviation|trademark|symbol"

    private static func extractPartOfSpeech(from text: String) -> String? {
        guard let firstPipe = text.range(of: "|"),
              let secondPipe = text.range(of: "|", range: firstPipe.upperBound..<text.endIndex) else {
            return nil
        }
        let remainder = String(text[secondPipe.upperBound...]).trimmingCharacters(in: .whitespaces)
        let pattern = try! NSRegularExpression(pattern: "^(\(partOfSpeechWords))\\b", options: [.caseInsensitive])
        let ns = remainder as NSString
        guard let match = pattern.firstMatch(in: remainder, range: NSRange(location: 0, length: ns.length)) else {
            return nil
        }
        return ns.substring(with: match.range(at: 1)).lowercased()
    }

    /// Dictionary Services returns one flat, unbroken string per entry: no
    /// newlines. Senses are marked by sequential numbers ("1 ... 2 ... 3 ..."),
    /// sub-senses by "•", and trailing sections by all-caps headers (ORIGIN,
    /// PHRASES, DERIVATIVES, USAGE). This pulls out every sense and sub-sense,
    /// each with its own example when the entry has one, favoring completeness
    /// over brevity.
    private static func parseItems(_ text: String) -> [DefinitionItem] {
        let core = firstPartOfSpeechBlock(coreEntryText(text))
        let senses = splitIntoSenses(core)

        var items: [DefinitionItem] = []
        for (number, senseText) in senses {
            let parts = senseText.components(separatedBy: "\u{2022}")
            for (index, part) in parts.enumerated() {
                let isSubItem = index > 0
                let cleaned = stripLeadingTags(part)
                guard !cleaned.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

                let (definition, example) = splitDefinitionAndExample(cleaned)
                guard !definition.isEmpty else { continue }

                items.append(DefinitionItem(
                    number: isSubItem ? nil : number,
                    text: definition,
                    example: example,
                    isSubItem: isSubItem
                ))
            }
        }
        return items
    }

    private static func splitDefinitionAndExample(_ text: String) -> (definition: String, example: String?) {
        guard let colonRange = text.range(of: ":") else {
            return (text.trimmingCharacters(in: .whitespaces), nil)
        }
        let definition = String(text[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        var example = String(text[colonRange.upperBound...]).components(separatedBy: "|")[0]
        example = stripLeadingTags(example).trimmingCharacters(in: .whitespaces)
        return (definition, example.isEmpty ? nil : example)
    }

    /// Apple's dictionary entries consistently place the etymology last, as
    /// an "ORIGIN ..." section at the very end of the whole entry (after any
    /// PHRASES/DERIVATIVES/USAGE sections) — so this searches the full,
    /// untruncated text rather than the "core" text used for definitions.
    private static func extractOrigin(from text: String) -> String? {
        guard let range = text.range(of: " ORIGIN ") ?? text.range(of: " ORIGIN") else { return nil }
        let origin = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        return origin.isEmpty ? nil : origin
    }

    /// NOAD entries with multiple parts of speech restart sense numbering at
    /// 1 for each one (e.g. "run" has 13 verb senses, then "noun 1 ... 14").
    /// Since only one part of speech is shown in the header/synonyms, this
    /// bounds parsing to that first block — otherwise the second block's
    /// sense numbers collide with the first's, and text after the last
    /// number the sequential matcher recognizes silently gets swallowed into
    /// the previous item's example (visibly corrupting entries like "run",
    /// "go", "set", "take").
    private static func firstPartOfSpeechBlock(_ text: String) -> String {
        // Where the header (word, pronunciation, first part-of-speech label)
        // ends — a genuine second part-of-speech block can only start well
        // after this. Matching this way (rather than assuming the header
        // itself matches the pattern below and skipping its first match) is
        // robust to headers the pattern doesn't cleanly match, e.g. ones
        // with a "[with object]"-style tag before the first sense number.
        guard let firstPipe = text.range(of: "|"),
              let secondPipe = text.range(of: "|", range: firstPipe.upperBound..<text.endIndex) else {
            return text
        }
        let headerEnd = text.distance(from: text.startIndex, to: secondPipe.upperBound)

        // A genuine new part-of-speech block always starts immediately after
        // the previous sense's closing period (NOAD's entries are one flat
        // run-on string, so there's no other separator) — unlike a numbered
        // restart, this also catches single-sense blocks with no "1" at all
        // (e.g. a bare trailing "adverb ..." sense).
        let pattern = try! NSRegularExpression(
            pattern: "(?<=\\.\\s)(\(partOfSpeechWords))\\b",
            options: [.caseInsensitive]
        )
        let nsText = text as NSString
        let matches = pattern.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        guard let secondBlock = matches.first(where: { $0.range.location > headerEnd + 20 }) else {
            return text
        }
        return nsText.substring(to: secondBlock.range.location)
    }

    /// Drops the etymology/phrases/derivatives/usage-note trailer that follows
    /// the numbered senses.
    private static func coreEntryText(_ text: String) -> String {
        var cutIndex = text.endIndex
        for marker in ["ORIGIN", "PHRASES", "DERIVATIVES", "USAGE"] {
            if let range = text.range(of: " \(marker) ") ?? text.range(of: " \(marker)"),
               range.lowerBound < cutIndex {
                cutIndex = range.lowerBound
            }
        }
        return String(text[..<cutIndex])
    }

    /// Splits on sequential top-level sense numbers (1, 2, 3, ...), ignoring
    /// unrelated numbers elsewhere in the header (e.g. plural forms). Returns
    /// the whole core text as one unnumbered sense if no numbering is found.
    private static func splitIntoSenses(_ text: String) -> [(number: Int?, text: String)] {
        let pattern = try! NSRegularExpression(pattern: "(?<=\\s)([1-9][0-9]?)\\s(?=[A-Za-z\\[(])")
        let nsText = text as NSString
        let matches = pattern.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        var boundaries: [(number: Int, range: NSRange)] = []
        var expected = 1
        for match in matches {
            let digit = Int(nsText.substring(with: match.range(at: 1)))!
            if digit == expected {
                boundaries.append((expected, match.range))
                expected += 1
            }
        }

        guard !boundaries.isEmpty else {
            return [(nil, stripHeaderForSingleSense(text))]
        }

        var senses: [(number: Int?, text: String)] = []
        for (index, boundary) in boundaries.enumerated() {
            let start = boundary.range.location + boundary.range.length
            let end = index + 1 < boundaries.count ? boundaries[index + 1].range.location : nsText.length
            guard end > start else { continue }
            senses.append((boundary.number, nsText.substring(with: NSRange(location: start, length: end - start))))
        }
        return senses
    }

    /// For entries with a single, unnumbered sense: skips past the
    /// "word syllables | pronunciation |" header and the part-of-speech label.
    private static func stripHeaderForSingleSense(_ text: String) -> String {
        guard let firstPipe = text.range(of: "|"),
              let secondPipe = text.range(of: "|", range: firstPipe.upperBound..<text.endIndex) else {
            return text
        }
        var remainder = String(text[secondPipe.upperBound...]).trimmingCharacters(in: .whitespaces)

        let posPattern = try! NSRegularExpression(
            pattern: "^(\(partOfSpeechWords))\\.?\\s*(\\([^)]*\\)\\s*)*",
            options: [.caseInsensitive]
        )
        let nsRemainder = remainder as NSString
        if let match = posPattern.firstMatch(in: remainder, range: NSRange(location: 0, length: nsRemainder.length)),
           match.range.location == 0 {
            remainder = nsRemainder.replacingCharacters(in: match.range, with: "")
        }
        return remainder.trimmingCharacters(in: .whitespaces)
    }

    /// Strips leading grammar tags like "[no object]" or "[with object]".
    private static func stripLeadingTags(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespaces)
        while result.hasPrefix("[") {
            guard let closeRange = result.range(of: "]") else { break }
            result = String(result[closeRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            if result.hasPrefix(":") {
                result = String(result.dropFirst()).trimmingCharacters(in: .whitespaces)
            }
        }
        return result
    }
}
