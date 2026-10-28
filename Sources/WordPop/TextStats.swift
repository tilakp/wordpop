import Foundation
import NaturalLanguage

/// A wordy phrase ("in order to") or a cliche ("low-hanging fruit") and
/// the plainer words for it; an empty fix means the phrase can go.
struct PhraseFlag: Equatable {
    let phrase: String
    let fix: String
    let isCliche: Bool
}

/// Readability notes for a selected passage, in the spirit of the
/// Hemingway editor: length, reading grade, long sentences, possible
/// passive voice, -ly adverbs and repeated words. All local.
struct TextStats: Equatable {
    let words: Int
    let sentences: Int
    /// Flesch-Kincaid grade level: the US school grade that can read it.
    let grade: Double
    let readingMinutes: Double
    /// Sentences over `longSentenceWords` words, with their word counts.
    let longSentences: [(text: String, words: Int)]
    /// Phrases like "was written", "are being held".
    let passives: [String]
    let adverbs: [String]
    /// Content words used three times or more, most used first.
    let repeated: [(word: String, count: Int)]
    /// Wordy phrases and cliches found in the passage, in its spelling
    /// and in order of use.
    var wordy: [PhraseFlag] = []
    /// The passage's sentences, for finding the one a note refers to.
    var sentenceTexts: [String] = []

    /// Each sentence's word count, in order.
    var sentenceLengths: [Int] { sentenceTexts.map { $0.split(whereSeparator: \.isWhitespace).count } }

    /// The longest run of three or more sentences in a row whose lengths
    /// are within two words of each other, which reads flat; nil when
    /// there is none.
    var evenRun: ClosedRange<Int>? {
        let lengths = sentenceLengths
        var best: ClosedRange<Int>?
        var start = 0
        for end in lengths.indices {
            while lengths[start...end].max()! - lengths[start...end].min()! > 2 { start += 1 }
            if end - start >= 2, end - start > (best.map { $0.count - 1 } ?? -1) { best = start...end }
        }
        return best
    }

    /// The sentence a passive phrase ("was written") occurs in.
    func sentence(containing phrase: String) -> String? {
        sentenceTexts.first { $0.lowercased().contains(phrase) }
    }

    static let longSentenceWords = 25
    /// A selection of at least this many words is a passage, not a word
    /// to look up.
    static let passageWords = 8
    /// A selection of at least this many words that ends like a sentence
    /// is one too, so a short sentence can be reframed. Idioms are
    /// shorter, or have no closing period.
    static let sentenceWords = 5

    static func == (a: TextStats, b: TextStats) -> Bool {
        a.words == b.words && a.sentences == b.sentences && a.grade == b.grade && a.passives == b.passives
            && a.adverbs == b.adverbs && a.longSentences.map(\.text) == b.longSentences.map(\.text)
            && a.repeated.map(\.word) == b.repeated.map(\.word) && a.wordy == b.wordy
    }

    static func isPassage(_ text: String) -> Bool {
        let count = text.split(whereSeparator: \.isWhitespace).count
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"\u{201D}')\u{2019}")))
        return count >= passageWords || count >= sentenceWords && [".", "!", "?"].contains(where: trimmed.hasSuffix)
    }

    /// How many times `lemma` or one of its forms is used in `paragraph`
    /// ("run", "runs", "ran"); 0 for short and common words, which are
    /// used again and again in any text.
    static func uses(of lemma: String, forms: [String], in paragraph: String) -> Int {
        let lemma = lemma.lowercased()
        guard lemma.count >= 4, !lemma.contains(" "), !stopWords.contains(lemma) else { return 0 }
        return occurrences(of: lemma, forms: forms, in: paragraph)
    }

    /// How many times `lemma` or one of its forms is used in `text`, for
    /// any word, short and common ones included.
    static func occurrences(of lemma: String, forms: [String] = [], in text: String) -> Int {
        let lemma = lemma.lowercased()
        return tokens(of: text, unit: .word).filter { range in
            let token = text[range].lowercased()
            return token == lemma || Inflection.form(of: token, lemma: lemma, forms: forms) != .plain
        }.count
    }

    /// `syllables` gives a word's syllable count when known (from the
    /// bundled CMU data); other words are counted by spelling. `flags` are
    /// the wordy phrases and cliches to look for.
    static func analyze(_ text: String, syllables: ([String]) -> [String: Int] = { _ in [:] }, flags: [PhraseFlag] = []) -> TextStats {
        let sentenceRanges = tokens(of: text, unit: .sentence)
        let sentenceTexts = sentenceRanges.map { text[$0].trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let wordRanges = tokens(of: text, unit: .word)
        let words = wordRanges.map { String(text[$0]) }.filter { $0.contains(where: \.isLetter) }
        let lowered = words.map { $0.lowercased() }

        let known = syllables(Array(Set(lowered)))
        let syllableTotal = lowered.reduce(0) { $0 + (known[$1] ?? estimatedSyllables($1)) }
        let wordCount = max(words.count, 1), sentenceCount = max(sentenceTexts.count, 1)
        let grade = 0.39 * Double(wordCount) / Double(sentenceCount) + 11.8 * Double(syllableTotal) / Double(wordCount) - 15.59

        let longSentences = sentenceTexts.compactMap { sentence -> (String, Int)? in
            let count = sentence.split(whereSeparator: \.isWhitespace).count
            return count > longSentenceWords ? (sentence, count) : nil
        }

        return TextStats(
            words: words.count,
            sentences: sentenceTexts.count,
            grade: max(0, (grade * 10).rounded() / 10),
            readingMinutes: Double(words.count) / 238,
            longSentences: longSentences,
            passives: passives(in: lowered),
            adverbs: adverbs(in: text),
            repeated: repeatedWords(in: lowered),
            wordy: flagged(flags, in: text),
            sentenceTexts: sentenceTexts
        )
    }

    /// The flagged phrases in `text`, matched as whole words in any case.
    /// The longest match wins where two overlap: "due to the fact that",
    /// not "the fact that" inside it.
    static func flagged(_ flags: [PhraseFlag], in text: String) -> [PhraseFlag] {
        let ns = text as NSString
        var taken: [NSRange] = []
        var found: [(location: Int, flag: PhraseFlag)] = []
        for flag in flags.sorted(by: { $0.phrase.count > $1.phrase.count }) {
            guard let pattern = try? NSRegularExpression(
                pattern: "\\b\(NSRegularExpression.escapedPattern(for: flag.phrase))\\b", options: .caseInsensitive
            ) else { continue }
            for match in pattern.matches(in: text, range: NSRange(location: 0, length: ns.length))
            where !taken.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) {
                taken.append(match.range)
                let spelled = ns.substring(with: match.range)
                if !found.contains(where: { $0.flag.phrase.lowercased() == spelled.lowercased() }) {
                    found.append((match.range.location, PhraseFlag(phrase: spelled, fix: flag.fix, isCliche: flag.isCliche)))
                }
            }
        }
        return found.sorted { $0.location < $1.location }.map(\.flag)
    }

    /// `text` with each phrase (the keys, as whole words in any case)
    /// changed to its fix in the same capitalization. An empty fix takes
    /// the phrase out with the commas and space around it, and capitalizes
    /// the next word when the phrase began the sentence: "Needless to
    /// say, it failed." -> "It failed."; "We were, needless to say, late."
    /// -> "We were late."
    static func tightened(_ text: String, fixes: [String: String]) -> String {
        var result = text
        for (phrase, fix) in fixes {
            let (head, tail) = fix.isEmpty ? (",?\\s*", ",?\\s*") : ("", "")
            guard let pattern = try? NSRegularExpression(
                pattern: "\(head)\\b\(NSRegularExpression.escapedPattern(for: phrase))\\b\(tail)", options: .caseInsensitive
            ) else { continue }
            for match in pattern.matches(in: result, range: NSRange(location: 0, length: (result as NSString).length)).reversed() {
                let ns = result as NSString
                let original = ns.substring(with: match.range)
                if fix.isEmpty {
                    // One space stays between the words on either side; a
                    // capital moves on to the next word.
                    let leading = original.prefix { $0 == "," || $0.isWhitespace }
                    let after = NSMaxRange(match.range)
                    var next = after < ns.length ? ns.substring(with: NSRange(location: after, length: 1)) : ""
                    let endsSentence = next.isEmpty || next.first?.isPunctuation == true
                    let gap = leading.isEmpty || endsSentence ? "" : " "
                    if original.dropFirst(leading.count).first?.isUppercase == true { next = next.uppercased() }
                    result = ns.replacingCharacters(
                        in: NSRange(location: match.range.location, length: match.range.length + next.utf16.count), with: gap + next
                    )
                } else {
                    result = ns.replacingCharacters(in: match.range, with: TextReplacer.matchingCase(of: original, fix))
                }
            }
        }
        return result
    }

    private static func tokens(of text: String, unit: NLTokenUnit) -> [Range<String.Index>] {
        let tokenizer = NLTokenizer(unit: unit)
        tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex)
    }

    private static let beForms: Set<String> = ["am", "is", "are", "was", "were", "be", "been", "being"]
    private static let irregularParticiples: Set<String> = [
        "done", "made", "given", "taken", "seen", "written", "held", "built", "found", "told", "said", "sent", "kept",
        "left", "brought", "bought", "caught", "taught", "thought", "known", "shown", "born", "chosen", "driven",
        "eaten", "fallen", "forgotten", "hidden", "broken", "spoken", "stolen", "worn", "torn", "won", "lost", "paid",
        "put", "cut", "hit", "read", "led", "met", "sold", "understood", "begun", "drawn", "grown", "thrown", "beaten",
    ]
    private static let notParticiples: Set<String> = ["need", "red", "bed", "seed", "speed", "feed", "often", "even", "open", "ten", "then", "when"]

    /// A form of "be", optionally followed by one -ly adverb or "being",
    /// then a past participle: "was written", "is being held", "were
    /// quickly sold". Like any such check it also catches some adjectives
    /// ("was tired"), so the popup calls them possible.
    private static func passives(in words: [String]) -> [String] {
        var found: [String] = []
        for (index, word) in words.enumerated() where beForms.contains(word) {
            var next = index + 1
            while next < words.count, next <= index + 2, words[next].hasSuffix("ly") || words[next] == "being" { next += 1 }
            guard next < words.count else { continue }
            let candidate = words[next]
            let looksLikeParticiple = irregularParticiples.contains(candidate)
                || (candidate.count > 3 && (candidate.hasSuffix("ed") || candidate.hasSuffix("en")) && !notParticiples.contains(candidate))
            if looksLikeParticiple {
                let phrase = words[index...next].joined(separator: " ")
                if !found.contains(phrase) { found.append(phrase) }
            }
        }
        return found
    }

    /// -ly adverbs as the language tagger marks them, in order of use.
    private static func adverbs(in text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var found: [String] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let word = text[range].lowercased()
            if tag == .adverb, word.hasSuffix("ly"), word.count > 4, !found.contains(word) { found.append(word) }
            return true
        }
        return found
    }

    static let stopWords: Set<String> = [
        "that", "this", "with", "from", "have", "were", "they", "their", "there", "what", "when", "which", "would",
        "could", "should", "about", "into", "than", "then", "them", "these", "those", "been", "will", "your", "just",
        "some", "more", "also", "only", "very", "over", "such", "like", "each", "other", "after", "before", "because",
        "while", "where", "does", "said", "here", "being",
    ]

    private static func repeatedWords(in words: [String]) -> [(word: String, count: Int)] {
        var counts: [String: Int] = [:]
        for word in words where word.count >= 4 && !stopWords.contains(word) { counts[word, default: 0] += 1 }
        return counts.filter { $0.value >= 3 }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(6).map { ($0.key, $0.value) }
    }

    /// Vowel groups, less a silent final e: a fallback for words the CMU
    /// data does not list.
    static func estimatedSyllables(_ word: String) -> Int {
        var count = 0, previousWasVowel = false
        for character in word {
            let vowel = "aeiouy".contains(character)
            if vowel && !previousWasVowel { count += 1 }
            previousWasVowel = vowel
        }
        if word.hasSuffix("e"), !word.hasSuffix("le"), count > 1 { count -= 1 }
        return max(count, 1)
    }
}
