import AppKit
import NaturalLanguage

/// A writer's own style rules, and presets such as Simplified Technical
/// English, in one plain-text format:
///
///     # A comment.
///     leverage | use          a word or phrase to avoid, and its fix
///     very                    a word to flag, with no fix
///     max sentence words: 20
///     max paragraph sentences: 6
///     flag -ing words
struct StyleRules: Equatable {
    var avoid: [PhraseFlag] = []
    var maxSentenceWords: Int?
    var maxParagraphSentences: Int?
    var flagsIngWords = false

    var isEmpty: Bool { self == StyleRules() }

    static func parse(_ text: String) -> StyleRules {
        var rules = StyleRules()
        for line in text.components(separatedBy: .newlines) {
            let line = line.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let lower = line.lowercased()
            if let number = setting(lower, "max sentence words:") {
                rules.maxSentenceWords = number
            } else if let number = setting(lower, "max paragraph sentences:") {
                rules.maxParagraphSentences = number
            } else if lower == "flag -ing words" {
                rules.flagsIngWords = true
            } else {
                let parts = line.components(separatedBy: "|")
                let phrase = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                let fix = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
                if !phrase.isEmpty { rules.avoid.append(PhraseFlag(phrase: phrase, fix: fix, isCliche: false)) }
            }
        }
        return rules
    }

    private static func setting(_ line: String, _ name: String) -> Int? {
        guard line.hasPrefix(name) else { return nil }
        return Int(line.dropFirst(name.count).trimmingCharacters(in: .whitespaces))
    }

    /// `other`'s rules added to these; its limits win where both set one,
    /// and its fix wins for a phrase both list.
    func merged(with other: StyleRules) -> StyleRules {
        var result = self
        let replaced = Set(other.avoid.map(\.phrase))
        result.avoid = avoid.filter { !replaced.contains($0.phrase) } + other.avoid
        result.maxSentenceWords = other.maxSentenceWords ?? maxSentenceWords
        result.maxParagraphSentences = other.maxParagraphSentences ?? maxParagraphSentences
        result.flagsIngWords = flagsIngWords || other.flagsIngWords
        return result
    }

    // MARK: Where the rules come from

    enum Preset: String, CaseIterable, Identifiable {
        case none, ste

        var id: String { rawValue }
        var label: String {
            switch self {
            case .none: "None"
            case .ste: "Simplified Technical English (ASD-STE100)"
            }
        }
    }

    static let presetKey = "WordPop.stylePreset"

    static var preset: Preset {
        UserDefaults.standard.string(forKey: presetKey).flatMap(Preset.init) ?? .none
    }

    /// ~/Library/Application Support/WordPop/Style Rules.txt
    static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WordPop/Style Rules.txt")
    }

    /// The chosen preset with the user's own rules on top, read each time
    /// so an edit to the file counts at the next lookup.
    static var current: StyleRules {
        let base = preset == .none ? StyleRules() : parse(Database.preset(named: preset.rawValue) ?? "")
        let own = (try? String(contentsOf: fileURL, encoding: .utf8)).map(parse) ?? StyleRules()
        return base.merged(with: own)
    }

    static let template = """
        # WordPop style rules. One rule per line; lines that start with # are notes.
        # Notes on a passage list what breaks these rules. Save this file and
        # select the text again to see the change.
        #
        # A word or phrase to avoid, and what to write instead:
        #   leverage | use
        # A word or phrase to flag only, with no fix:
        #   very
        # Limits and checks:
        #   max sentence words: 20
        #   max paragraph sentences: 6
        #   flag -ing words

        """

    /// Opens the user's rules file in their text editor, made from the
    /// template the first time.
    static func openFile() {
        let url = fileURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? template.write(to: url, atomically: true, encoding: .utf8)
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: Checking a passage

    /// What a passage does against the rules.
    struct Report: Equatable {
        /// Words and phrases to avoid, in the passage's spelling and order.
        var words: [PhraseFlag] = []
        /// Sentences over the word limit, and the limit.
        var longSentences: [String] = []
        var sentenceLimit: Int?
        /// Sentence counts of paragraphs over the limit, by paragraph number
        /// (from 1).
        var longParagraphs: [(number: Int, sentences: Int)] = []
        var ingWords: [String] = []

        var isEmpty: Bool { words.isEmpty && longSentences.isEmpty && longParagraphs.isEmpty && ingWords.isEmpty }

        static func == (a: Report, b: Report) -> Bool {
            a.words == b.words && a.longSentences == b.longSentences && a.longParagraphs.map(\.number) == b.longParagraphs.map(\.number)
                && a.ingWords == b.ingWords
        }
    }

    func check(_ text: String, sentences: [String]) -> Report {
        var report = Report()
        report.words = TextStats.flagged(avoid, in: text)
        if let limit = maxSentenceWords {
            report.sentenceLimit = limit
            report.longSentences = sentences.filter { $0.split(whereSeparator: \.isWhitespace).count > limit }
        }
        if let limit = maxParagraphSentences {
            let paragraphs = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            for (index, paragraph) in paragraphs.enumerated() {
                let tokenizer = NLTokenizer(unit: .sentence)
                tokenizer.string = paragraph
                let count = tokenizer.tokens(for: paragraph.startIndex..<paragraph.endIndex).count
                if count > limit { report.longParagraphs.append((index + 1, count)) }
            }
        }
        if flagsIngWords { report.ingWords = Self.ingVerbs(in: text) }
        return report
    }

    /// Verbs that end in "-ing" ("checking", "having"), which STE does not
    /// use; verbs whose base form ends so ("bring", "sing") are not -ing
    /// forms.
    static func ingVerbs(in text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var found: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let word = text[range].lowercased()
            if tag == .verb, word.hasSuffix("ing"), word.count > 4, !baseFormsInIng.contains(word), !found.contains(word) { found.append(word) }
            return true
        }
        return found
    }

    private static let baseFormsInIng: Set<String> = ["bring", "cling", "fling", "sling", "sting", "swing", "spring", "string", "wring", "thing"]
}
