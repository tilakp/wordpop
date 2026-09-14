import CoreServices
import Foundation

struct DefinitionItem {
    let number: Int?
    let text: String
    let example: String?
    let isSubItem: Bool
    /// Register or region label ("informal", "mainly British English").
    var label: String? = nil
}

/// One part-of-speech section of an entry ("run" the verb, "run" the
/// noun), with the synonyms and antonyms that belong to that sense group.
struct PartOfSpeechBlock {
    let partOfSpeech: String?
    let items: [DefinitionItem]
    /// Sense-grouped synonyms from the system Thesaurus; empty when it has
    /// no entry for this word and part of speech.
    let senses: [ThesaurusSense]
    /// Flat fallback lists (WordNet + Moby) used when `senses` is empty.
    let synonyms: [String]
    let antonyms: [String]
}

struct WordEntry {
    let word: String
    /// The headword with syllable dots ("me·tic·u·lous"), when the entry has them.
    let syllables: String?
    let pronunciation: String?
    /// Inflected forms as the dictionary lists them: "runs", "past ran".
    let forms: [String]
    let blocks: [PartOfSpeechBlock]
    let rhymes: [String]
    let nearRhymes: [String]
    let origin: String?
    /// Idioms and phrasal verbs from the entry's PHRASES and PHRASAL VERBS sections.
    let phrases: [Phrase]
    /// Name of the dictionary the entry came from when it is not the
    /// default English one (a bilingual dictionary the user enabled).
    let source: String?
    let found: Bool

    static let empty = WordEntry(
        word: "", syllables: nil, pronunciation: nil, forms: [], blocks: [], rhymes: [], nearRhymes: [],
        origin: nil, phrases: [], source: nil, found: false
    )
}

/// Looks up a word using macOS's built-in Dictionary Services (the same data
/// that powers Dictionary.app / the trackpad "Look Up" popover) for
/// definitions, examples and pronunciation. Fully offline, in-memory, no
/// network calls. Synonyms come from a bundled dataset (see SynonymStore)
/// since Dictionary Services has no public API for its separate Thesaurus.
enum DictionaryLookup {
    static func lookup(_ rawText: String) -> WordEntry {
        let word = headword(in: rawText)
        let entryText = rawEntryText(for: word)
        // The flat text always starts with the canonical headword, so an
        // inflected selection ("running") resolves to its entry ("run")
        // before the structured record is fetched by exact match.
        let canonical = entryText.map(canonicalHeadword(in:)) ?? word
        let thesaurus = Thesaurus.blocks(for: canonical)

        if let dictionary = SystemDictionaries.english,
           let parsed = EntryMarkupParser.merge(
               SystemDictionaries.entryMarkups(of: canonical, in: dictionary).compactMap(EntryMarkupParser.parse)
           ) {
            return entry(from: parsed, thesaurus: thesaurus)
        }
        return entry(word: canonical, entryText: entryText, thesaurus: thesaurus)
    }

    /// Builds the entry from a parsed markup record.
    static func entry(from parsed: EntryMarkupParser.Parsed, thesaurus: [ThesaurusBlock]) -> WordEntry {
        let word = parsed.title
        return assemble(
            word: word, syllables: parsed.syllables, pronunciation: parsed.pronunciation, forms: parsed.forms,
            blocks: parsed.blocks, origin: parsed.origin, phrases: parsed.phrases, thesaurus: thesaurus
        )
    }

    /// Builds the entry from the flat definition text (the fallback when no
    /// structured record matches), so parsing can be exercised on fixtures
    /// without Dictionary Services.
    static func entry(word: String, entryText: String?, thesaurus: [ThesaurusBlock]) -> WordEntry {
        guard let entryText else {
            let rhymes = RhymeStore.rhymes(for: word)
            let nearRhymes = RhymeStore.nearRhymes(for: word)
            if let fallback = fallbackEntry(for: word, rhymes: rhymes, nearRhymes: nearRhymes) {
                return fallback
            }
            var blocks = thesaurus.map { block(word, partOfSpeech: $0.partOfSpeech, items: [], thesaurus: thesaurus) }
            if blocks.isEmpty {
                let fallback = block(word, partOfSpeech: nil, items: [], thesaurus: [])
                if !fallback.synonyms.isEmpty || !fallback.antonyms.isEmpty { blocks = [fallback] }
            }
            return WordEntry(
                word: word, syllables: nil, pronunciation: nil, forms: [], blocks: blocks, rhymes: rhymes,
                nearRhymes: nearRhymes, origin: nil, phrases: [], source: nil,
                found: !blocks.isEmpty || !rhymes.isEmpty || !nearRhymes.isEmpty
            )
        }

        let header = parseHeader(entryText)
        return assemble(
            word: word, syllables: header.syllables, pronunciation: extractPronunciation(from: entryText),
            forms: header.forms, blocks: partOfSpeechBlocks(entryText), origin: extractOrigin(from: entryText),
            phrases: [], thesaurus: thesaurus
        )
    }

    private static func assemble(
        word: String, syllables: String?, pronunciation: String?, forms: [String],
        blocks parsedBlocks: [(partOfSpeech: String?, items: [DefinitionItem])],
        origin: String?, phrases: [Phrase], thesaurus: [ThesaurusBlock]
    ) -> WordEntry {
        var blocks = parsedBlocks.map { block(word, partOfSpeech: $0.partOfSpeech, items: $0.items, thesaurus: thesaurus) }
        for extra in thesaurus where !blocks.contains(where: { $0.partOfSpeech == extra.partOfSpeech }) {
            blocks.append(block(word, partOfSpeech: extra.partOfSpeech, items: [], thesaurus: thesaurus))
        }
        return WordEntry(
            word: word,
            syllables: syllables,
            pronunciation: pronunciation,
            forms: forms,
            blocks: blocks,
            rhymes: RhymeStore.rhymes(for: word),
            nearRhymes: RhymeStore.nearRhymes(for: word),
            origin: origin,
            phrases: phrases,
            source: nil,
            found: true
        )
    }

    /// The headword as the flat text spells it: everything before the first
    /// pipe, minus the syllabified repeat and any homograph number
    /// ("meticulous me·tic·u·lous |", "go 1 |").
    static func canonicalHeadword(in entryText: String) -> String {
        guard let pipe = entryText.range(of: "|") else { return headword(in: entryText) }
        let tokens = entryText[..<pipe.lowerBound].split(separator: " ").map(String.init)
            .filter { !$0.contains("\u{B7}") && Int($0) == nil }
        return tokens.joined(separator: " ")
    }

    private static func block(_ word: String, partOfSpeech: String?, items: [DefinitionItem], thesaurus: [ThesaurusBlock]) -> PartOfSpeechBlock {
        let senses = thesaurus.first { $0.partOfSpeech == partOfSpeech }?.senses ?? []
        return PartOfSpeechBlock(
            partOfSpeech: partOfSpeech,
            items: items,
            senses: senses,
            synonyms: SynonymStore.synonyms(for: word, partOfSpeech: partOfSpeech),
            antonyms: AntonymStore.antonyms(for: word, partOfSpeech: partOfSpeech)
        )
    }

    /// For words the English dictionary lacks, try the other dictionaries
    /// the user enabled in Dictionary.app (typically bilingual ones). Their
    /// entry formats vary, so the text is shown as one unparsed definition.
    private static func fallbackEntry(for word: String, rhymes: [String], nearRhymes: [String]) -> WordEntry? {
        for dictionary in SystemDictionaries.fallbacks {
            guard var text = SystemDictionaries.definition(of: word, in: dictionary) else { continue }
            if text.lowercased().hasPrefix(word.lowercased()) {
                text = String(text.dropFirst(word.count)).trimmingCharacters(in: .whitespaces)
            }
            let item = DefinitionItem(number: nil, text: text, example: nil, isSubItem: false)
            return WordEntry(
                word: word, syllables: nil, pronunciation: nil, forms: [],
                blocks: [PartOfSpeechBlock(partOfSpeech: nil, items: [item], senses: [], synonyms: [], antonyms: [])],
                rhymes: rhymes, nearRhymes: nearRhymes, origin: nil, phrases: [],
                source: SystemDictionaries.name(of: dictionary), found: true
            )
        }
        return nil
    }

    /// Turns whatever the user selected into something worth looking up:
    /// surrounding quotes and punctuation are dropped, and if the selection
    /// runs on past a single term, only the term Dictionary Services
    /// recognizes at the start is kept — so a selected sentence looks up
    /// its first word, while "ice cream" survives as a phrase.
    static func headword(in rawText: String) -> String {
        let collapsed = rawText
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        let trimmed = collapsed.trimmingCharacters(in: CharacterSet.letters.union(.decimalDigits).inverted)
        guard !trimmed.isEmpty else { return trimmed }

        let cfText = trimmed as CFString
        let termRange = DCSGetTermRangeInString(nil, cfText, 0)
        guard termRange.location == 0, termRange.length > 0,
              termRange.length < CFStringGetLength(cfText),
              let term = CFStringCreateWithSubstring(nil, cfText, termRange) as String? else {
            return trimmed
        }
        return term
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

    /// The header runs "word syl·la·bles | pronunciation | part-of-speech
    /// (inflections) ...". Inflection groups look like "(runs)",
    /// "(, running | ˈrəniNG |)", "(past; ran | ran |)", "(plural children)"
    /// or "(third singular present goes; present participle going; ...)".
    private static func parseHeader(_ text: String) -> (syllables: String?, forms: [String]) {
        guard let firstPipe = text.range(of: "|"),
              let secondPipe = text.range(of: "|", range: firstPipe.upperBound..<text.endIndex) else {
            return (nil, [])
        }
        // "United Nations U·nit·ed Na·tions |": the syllabified form is
        // every token from the first dotted one onward.
        let titleTokens = text[..<firstPipe.lowerBound].split(separator: " ").map(String.init)
        let syllables = titleTokens.firstIndex { $0.contains("\u{B7}") }
            .map { titleTokens[$0...].joined(separator: " ") }

        var remainder = Substring(text[secondPipe.upperBound...]).drop(while: \.isWhitespace)
        let label = try! NSRegularExpression(pattern: "^(\(partOfSpeechWords))\\.?\\s*", options: [.caseInsensitive])
        let nsRemainder = String(remainder) as NSString
        if let match = label.firstMatch(in: String(remainder), range: NSRange(location: 0, length: nsRemainder.length)) {
            remainder = remainder.dropFirst(nsRemainder.substring(with: match.range).count)
        }

        var forms: [String] = []
        while remainder.first == "(", let close = matchingParenthesis(in: remainder) {
            let inner = String(remainder[remainder.index(after: remainder.startIndex)..<close])
            forms += parseFormGroup(inner)
            remainder = remainder[remainder.index(after: close)...].drop(while: \.isWhitespace)
        }
        return (syllables, forms)
    }

    private static let formLabelWords: Set<String> = [
        "past", "participle", "present", "plural", "singular", "third", "person",
        "comparative", "superlative", "feminine", "masculine", "or",
    ]

    private static func matchingParenthesis(in text: Substring) -> Substring.Index? {
        var depth = 0
        for index in text.indices {
            switch text[index] {
            case "(": depth += 1
            case ")":
                depth -= 1
                if depth == 0 { return index }
            default: break
            }
        }
        return nil
    }

    /// Within a group, "| ... |" pronunciations are dropped, then ";" separates
    /// either whole "label form" entries or a bare label from the form that
    /// follows it ("past; ran").
    private static func parseFormGroup(_ inner: String) -> [String] {
        let cleaned = inner
            .replacingOccurrences(of: "\\s*\\|[^|]*\\|", with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: ", "))
        let segments = cleaned.components(separatedBy: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var forms: [String] = []
        var pendingLabel: String?
        for (index, segment) in segments.enumerated() {
            let words = segment.split(separator: " ").map(String.init)
            if let first = words.first, ["abbreviation", "abbr", "also", "symbol"].contains(first.lowercased()) {
                continue
            }
            if index < segments.count - 1, words.allSatisfy(formLabelWords.contains) {
                pendingLabel = segment
                continue
            }
            forms.append(pendingLabel.map { "\($0) \(segment)" } ?? segment)
            pendingLabel = nil
        }
        return forms
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
    /// PHRASES, DERIVATIVES, USAGE). Entries with several parts of speech
    /// restart the numbering for each ("run" has 13 verb senses, then
    /// "noun 1 ... 14"), so the text is split into part-of-speech blocks
    /// first and each block is parsed on its own — otherwise the second
    /// block's numbers collide with the first's and its text gets swallowed
    /// into the previous item's example.
    private static func partOfSpeechBlocks(_ text: String) -> [(partOfSpeech: String?, items: [DefinitionItem])] {
        let core = coreEntryText(text)
        let nsCore = core as NSString

        // Where the header (word, pronunciation, first part-of-speech label)
        // ends — a genuine new block can only start well after this.
        var headerEnd = 0
        if let firstPipe = core.range(of: "|"),
           let secondPipe = core.range(of: "|", range: firstPipe.upperBound..<core.endIndex) {
            headerEnd = core.distance(from: core.startIndex, to: secondPipe.upperBound)
        }

        // A new part-of-speech block always starts immediately after the
        // previous sense's closing period (the entry is one flat run-on
        // string, so there's no other separator) — unlike a numbered
        // restart, this also catches single-sense blocks with no "1" at all
        // (e.g. a bare trailing "adverb ..." sense).
        let pattern = try! NSRegularExpression(
            pattern: "(?<=\\.\\s)(\(partOfSpeechWords))\\b",
            options: [.caseInsensitive]
        )
        let starts = pattern.matches(in: core, range: NSRange(location: 0, length: nsCore.length))
            .filter { $0.range.location > headerEnd + 20 }

        var blocks: [(partOfSpeech: String?, items: [DefinitionItem])] = []
        var cursor = 0
        var label = extractPartOfSpeech(from: text)
        for match in starts + [nil] {
            let end = match?.range.location ?? nsCore.length
            let items = parseItems(nsCore.substring(with: NSRange(location: cursor, length: end - cursor)))
            if !items.isEmpty {
                if let index = blocks.firstIndex(where: { $0.partOfSpeech == label }) {
                    blocks[index].items += items
                } else {
                    blocks.append((label, items))
                }
            }
            guard let match else { break }
            cursor = end
            label = nsCore.substring(with: match.range(at: 1)).lowercased()
        }
        return blocks
    }

    private static func parseItems(_ blockText: String) -> [DefinitionItem] {
        let senses = splitIntoSenses(blockText)

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

    /// For blocks with a single, unnumbered sense: skips past the
    /// "word syllables | pronunciation |" header (first block only) and the
    /// part-of-speech label.
    private static func stripHeaderForSingleSense(_ text: String) -> String {
        var remainder = text.trimmingCharacters(in: .whitespaces)
        if let firstPipe = text.range(of: "|"),
           let secondPipe = text.range(of: "|", range: firstPipe.upperBound..<text.endIndex) {
            remainder = String(text[secondPipe.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        let posPattern = try! NSRegularExpression(pattern: "^(\(partOfSpeechWords))\\.?\\s*", options: [.caseInsensitive])
        let nsRemainder = remainder as NSString
        if let match = posPattern.firstMatch(in: remainder, range: NSRange(location: 0, length: nsRemainder.length)) {
            remainder = nsRemainder.substring(from: match.range.length)
        }
        // Inflection groups can nest parentheses inside their pronunciations
        // ("(plural children | ˈCHildr(ə)n |)"), so a regex cannot skip them.
        var rest = Substring(remainder).drop(while: \.isWhitespace)
        while rest.first == "(", let close = matchingParenthesis(in: rest) {
            rest = rest[rest.index(after: close)...].drop(while: \.isWhitespace)
        }
        return String(rest).trimmingCharacters(in: .whitespaces)
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
