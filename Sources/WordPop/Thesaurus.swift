import Foundation

struct ThesaurusSense {
    let example: String?
    let synonyms: [String]
    let antonyms: [String]
}

struct ThesaurusBlock {
    let partOfSpeech: String?
    let senses: [ThesaurusSense]
}

/// Reads the Oxford American Writer's Thesaurus (or the Oxford Thesaurus of
/// English) that ships with macOS. Its entries are one flat string:
///
///     run verb 1 she ran across the road. sprint, race, dart; informal
///     tear, pelt; archaic hie. ANTONYMS dawdle. 2 the men turned and ran.
///     flee, run away ... noun 1 a run of bad luck. spell, stretch ...
///
/// Register labels ("informal", "British English", "archaic") prefix a
/// semicolon-separated group and apply to every word in it.
enum Thesaurus {
    static func blocks(for word: String) -> [ThesaurusBlock] {
        guard let dictionary = SystemDictionaries.thesaurus,
              let raw = SystemDictionaries.definition(of: word, in: dictionary) else { return [] }
        return parse(raw, word: word)
    }

    static func parse(_ raw: String, word: String) -> [ThesaurusBlock] {
        var text = raw
        if text.lowercased().hasPrefix(word.lowercased()) {
            text = String(text.dropFirst(word.count))
        }
        text = text.trimmingCharacters(in: .whitespaces)

        let nsText = text as NSString
        let starts = partOfSpeechPattern.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard let first = starts.first, first.range.location == 0 else {
            return [ThesaurusBlock(partOfSpeech: nil, senses: senses(in: withoutTrailer(text)))]
        }

        var blocks: [ThesaurusBlock] = []
        for (index, match) in starts.enumerated() {
            let bodyStart = match.range.location + match.range.length
            let end = index + 1 < starts.count ? starts[index + 1].range.location : nsText.length
            let body = nsText.substring(with: NSRange(location: bodyStart, length: end - bodyStart))
            let parsed = senses(in: withoutTrailer(body))
            guard !parsed.isEmpty else { continue }
            blocks.append(ThesaurusBlock(partOfSpeech: nsText.substring(with: match.range(at: 1)).lowercased(), senses: parsed))
        }
        return blocks
    }

    /// Each part-of-speech block can end with idiom, usage or word-link
    /// sections that are not synonyms of the headword.
    private static func withoutTrailer(_ text: String) -> String {
        var cut = text.endIndex
        for marker in [" PHRASES ", " WORD LINKS ", " CHOOSE THE RIGHT WORD ", " THE RIGHT WORD ", " USAGE ", " WORD TOOLKIT ", "Word Links sections"] {
            if let range = text.range(of: marker), range.lowerBound < cut { cut = range.lowerBound }
        }
        return String(text[..<cut])
    }

    private static let partOfSpeechWords = "noun|verb|adjective|adverb|pronoun|preposition|conjunction|interjection|exclamation|determiner"
    private static let partOfSpeechPattern = try! NSRegularExpression(
        pattern: "(?:^|(?<=\\. ))(\(partOfSpeechWords))\\b\\s*", options: [.caseInsensitive]
    )
    private static let senseNumberPattern = try! NSRegularExpression(pattern: "(?:^|(?<=\\s))([1-9][0-9]?)\\s(?=\\S)")

    private static func senses(in body: String) -> [ThesaurusSense] {
        let nsBody = body as NSString
        var boundaries: [NSRange] = []
        var expected = 1
        for match in senseNumberPattern.matches(in: body, range: NSRange(location: 0, length: nsBody.length)) {
            if Int(nsBody.substring(with: match.range(at: 1))) == expected {
                boundaries.append(match.range)
                expected += 1
            }
        }
        guard !boundaries.isEmpty else {
            return [sense(from: body)].compactMap { $0 }
        }
        var result: [ThesaurusSense] = []
        for (index, boundary) in boundaries.enumerated() {
            let start = boundary.location + boundary.length
            let end = index + 1 < boundaries.count ? boundaries[index + 1].location : nsBody.length
            guard end > start, let sense = sense(from: nsBody.substring(with: NSRange(location: start, length: end - start))) else { continue }
            result.append(sense)
        }
        return result
    }

    private static func sense(from text: String) -> ThesaurusSense? {
        var body = text.trimmingCharacters(in: .whitespaces)
        var example: String?

        // The example sentence, when present, is the first period-terminated
        // clause. A synonym list also contains periods only at its end, so
        // tell the two apart by comma density: lists are mostly commas.
        if let stop = body.range(of: ". ") {
            let candidate = String(body[..<stop.lowerBound])
            let words = candidate.split(separator: " ").count
            let commas = candidate.filter { $0 == "," }.count
            if words >= 2, Double(commas) / Double(words) <= 0.2 {
                example = candidate.replacingOccurrences(of: " | ", with: " / ")
                body = String(body[stop.upperBound...])
            }
        }

        var antonymText = ""
        if let range = body.range(of: " ANTONYMS ") ?? body.range(of: "ANTONYMS ") {
            antonymText = String(body[range.upperBound...])
            body = String(body[..<range.lowerBound])
        }

        let synonyms = terms(in: body)
        let antonyms = terms(in: antonymText)
        guard !synonyms.isEmpty || !antonyms.isEmpty else { return nil }
        return ThesaurusSense(example: example, synonyms: Array(synonyms.prefix(12)), antonyms: Array(antonyms.prefix(8)))
    }

    private static let registerLabel = try! NSRegularExpression(
        pattern: "^(?:(?:informal|formal|literary|archaic|dated|rare|humorous|derogatory|vulgar slang|vulgar|slang|technical|"
            + "euphemistic|poetic\\/literary|poetic|historical|old-fashioned|offensive|dialect|"
            + "British English|North American English|Australian English|Australian\\/New Zealand English|New Zealand English|"
            + "Irish English|Scottish English|Indian English|South African English|Canadian English|Northern English|"
            + "law|medicine|computing|military|nautical|physics|chemistry|botany|zoology)[,\\s]+)+",
        options: [.caseInsensitive]
    )

    /// Unlabelled groups come first; labelled ones (informal, archaic,
    /// regional) keep their words but sort after, so the everyday synonyms
    /// lead the list.
    private static func terms(in text: String) -> [String] {
        var plain: [String] = []
        var labelled: [String] = []
        var seen = Set<String>()
        for group in text.components(separatedBy: ";") {
            var groupText = group.trimmingCharacters(in: CharacterSet(charactersIn: " ."))
            let nsGroup = groupText as NSString
            let isLabelled: Bool
            if let match = registerLabel.firstMatch(in: groupText, range: NSRange(location: 0, length: nsGroup.length)) {
                groupText = nsGroup.substring(from: match.range.length)
                isLabelled = true
            } else {
                isLabelled = false
            }
            for rawTerm in groupText.components(separatedBy: ",") {
                let term = rawTerm
                    .replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: CharacterSet(charactersIn: " ."))
                guard !term.isEmpty, !term.hasPrefix("and "), term.split(separator: " ").count <= 4,
                      seen.insert(term.lowercased()).inserted else { continue }
                if isLabelled { labelled.append(term) } else { plain.append(term) }
            }
        }
        return plain + labelled
    }
}
