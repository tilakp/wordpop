import Foundation
import NaturalLanguage

/// Quick changes to a selection's text, as PopClip extensions and
/// TextSoap make them: title case, sentence case, curly or straight
/// quotes, and lines joined into one paragraph. All local and rule-based.
enum TextTool: String, CaseIterable {
    case titleCase = "Title Case"
    case sentenceCase = "Sentence case"
    case curlyQuotes = "Curly quotes"
    case straightQuotes = "Straight quotes"
    case joinLines = "Join lines"

    func apply(to text: String) -> String {
        // A headline in all capitals has no case to keep.
        let text = [.titleCase, .sentenceCase].contains(self) && !text.contains(where: \.isLowercase) ? text.lowercased() : text
        return switch self {
        case .titleCase: TextTool.titleCase(text)
        case .sentenceCase: TextTool.sentenceCase(text)
        case .curlyQuotes: TextTool.curlyQuotes(text)
        case .straightQuotes: TextTool.straightQuotes(text)
        case .joinLines: TextTool.joinLines(text)
        }
    }

    /// The tools that would change `text`: title case only for a short
    /// headline, never for a passage of sentences, and sentence case only
    /// for text that looks title-cased or is in capitals, not for prose
    /// whose capitals are names.
    static func useful(for text: String) -> [TextTool] {
        let words = text.split(whereSeparator: \.isWhitespace)
        let headline = words.count <= 15 && !text.contains("\n")
        let capitalized = words.filter { $0.first?.isUppercase == true }.count
        let looksTitled = capitalized * 2 >= words.count || !text.contains(where: \.isLowercase)
        return allCases.filter { tool in
            if tool == .titleCase, !headline { return false }
            if tool == .sentenceCase, !looksTitled { return false }
            return tool.apply(to: text) != text
        }
    }

    /// Words a headline keeps in lowercase unless they start or end it,
    /// in AP style: articles, coordinating conjunctions, and prepositions
    /// of up to three letters.
    private static let minorWords: Set<String> = [
        "a", "an", "the", "and", "but", "or", "nor", "for", "so", "yet", "as", "at", "by", "in", "of", "off", "on",
        "per", "to", "up", "via", "vs",
    ]

    /// "a guide to writing for the web" -> "A Guide to Writing for the
    /// Web". Words with a capital inside ("iPhone") or in all capitals
    /// ("NASA") are kept as they are; each part of a hyphenated word and
    /// the first word after a colon are capitalized.
    static func titleCase(_ text: String) -> String {
        let words = text.components(separatedBy: " ")
        let last = words.lastIndex { $0.contains(where: \.isLetter) } ?? 0
        var startsPhrase = true
        return words.enumerated().map { index, word in
            defer { startsPhrase = word.hasSuffix(":") || word.hasSuffix("\u{2014}") || word.isEmpty && startsPhrase }
            guard word.contains(where: \.isLetter) else { return word }
            return word.components(separatedBy: "-").enumerated().map { part, piece in
                let bare = piece.trimmingCharacters(in: .letters.inverted).lowercased()
                let minor = part == 0 && !startsPhrase && index != last && minorWords.contains(bare)
                return minor ? lowered(piece) : capitalized(piece)
            }.joined(separator: "-")
        }.joined(separator: " ")
    }

    /// "The Quick Guide To Writing In Paris" -> "The quick guide to
    /// writing in Paris": a capital only at the start of each sentence,
    /// for "I", for names the language tagger knows (people, places,
    /// organizations), and for words in all capitals or with a capital
    /// inside. Other names lose their capital, so read the result.
    static func sentenceCase(_ text: String) -> String {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var names: [Range<String.Index>] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: [.omitWhitespace, .omitPunctuation, .joinNames]) { tag, range in
            if let tag, [.personalName, .placeName, .organizationName].contains(tag) { names.append(range) }
            return true
        }
        var result = ""
        var sentenceStart = true
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            guard character.isLetter else {
                if ".!?:".contains(character) { sentenceStart = true }
                result.append(character)
                index = text.index(after: index)
                continue
            }
            let end = text[index...].firstIndex { !$0.isLetter && $0 != "'" && $0 != "\u{2019}" } ?? text.endIndex
            let word = String(text[index..<end])
            let isName = names.contains { $0.contains(index) } || alwaysCapitalized.contains(word.lowercased())
            let pronoun = word.lowercased() == "i" || ["i'", "i\u{2019}"].contains { word.lowercased().hasPrefix($0) }
            let keep = isName || hasInnerCapital(word) || isAllCaps(word)
            result += keep ? word : sentenceStart || pronoun ? capitalized(word) : lowered(word)
            sentenceStart = false
            index = end
        }
        return result
    }

    /// Days and months, which keep their capital in any sentence.
    private static let alwaysCapitalized: Set<String> = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "january", "february", "april",
        "june", "july", "august", "september", "october", "november", "december",
    ]

    /// Straight quotes to curly ones: a quote opens at the start, after a
    /// space or an opening bracket or dash, and closes everywhere else, so
    /// an apostrophe ("don't", "'90s" excepted) becomes a closing single
    /// quote, as it should.
    static func curlyQuotes(_ text: String) -> String {
        var result = ""
        var previous: Character?
        for character in text {
            let opens = previous.map { $0.isWhitespace || "([{\u{2014}\u{2013}\"'\u{201C}\u{2018}".contains($0) } ?? true
            switch character {
            case "\"": result.append(opens ? "\u{201C}" : "\u{201D}")
            case "'": result.append(opens ? "\u{2018}" : "\u{2019}")
            default: result.append(character)
            }
            previous = result.last
        }
        return result
    }

    static func straightQuotes(_ text: String) -> String {
        String(text.map { character -> Character in
            switch character {
            case "\u{201C}", "\u{201D}": "\""
            case "\u{2018}", "\u{2019}": "'"
            default: character
            }
        })
    }

    /// Single line breaks become spaces, as in text copied from a PDF or
    /// an email; blank lines between paragraphs stay. A word broken with
    /// a hyphen at a line end is not joined, as the hyphen may be real.
    static func joinLines(_ text: String) -> String {
        let paragraphs = text.components(separatedBy: "\n\n")
        return paragraphs.map { paragraph in
            paragraph.split(separator: "\n", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: " ")
        }.joined(separator: "\n\n")
    }

    private static func capitalized(_ word: String) -> String {
        guard !hasInnerCapital(word), !isAllCaps(word), let first = word.firstIndex(where: \.isLetter) else { return word }
        return word[..<first] + word[first].uppercased() + word[word.index(after: first)...].lowercased()
    }

    private static func lowered(_ word: String) -> String {
        hasInnerCapital(word) || isAllCaps(word) ? word : word.lowercased()
    }

    /// "iPhone", "McDonald", "YouTube".
    private static func hasInnerCapital(_ word: String) -> Bool {
        word.dropFirst().contains(where: \.isUppercase) && word.contains(where: \.isLowercase)
    }

    /// "NASA", "STE", but not "I" or "A".
    private static func isAllCaps(_ word: String) -> Bool {
        let letters = word.filter(\.isLetter)
        return letters.count > 1 && letters.allSatisfy(\.isUppercase)
    }
}
