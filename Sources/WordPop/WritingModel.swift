import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Writing help from Apple's on-device language model (macOS 26 or later
/// with Apple Intelligence turned on). It runs locally, so nothing leaves
/// the Mac. Where the model is missing, every call returns no results and
/// the popup and Quick Search behave as before.
///
/// Each request first asks for a structured answer, which the model keeps
/// to best. Dictionary content (definitions with "illegal", "kill",
/// "drug") can trip the default guardrails, which then fail the request;
/// in that case it is asked again for a plain-text answer under the
/// permissive guardrails for transforming given text, which apply only to
/// plain text. Plain answers are parsed by `listItems` and `numbers`, and
/// every word that comes back is checked against the candidates or the
/// dictionary.
enum WritingModel {
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// Starts loading the model, called when the lookup shortcut is pressed
    /// so it is ready by the time the popup asks its first question.
    static func prewarm() {
        #if canImport(FoundationModels)
        if #available(macOS 26, *), isAvailable {
            LanguageModelSession(model: model).prewarm()
        }
        #endif
    }

    /// The candidates that can replace `word` in `sentence` without
    /// changing its meaning, best first.
    static func bestFits(for word: String, in sentence: String, candidates: [String]) async -> [String] {
        guard !candidates.isEmpty else { return [] }
        let words = await list(
            .fits,
            "You help a writer choose a synonym. Judge each candidate only by whether it can replace the word in the given sentence without changing its meaning or sounding wrong.",
            "Sentence: \(sentence)\nWord: \(word)\nCandidates: \(candidates.joined(separator: ", "))",
            format: "Answer with the candidates that fit, best first, separated by commas, and nothing else."
        )
        return pick(words, from: candidates)
    }

    /// Words that match a description ("the smell of rain on dry earth" ->
    /// petrichor). Three differently framed requests run in parallel, since
    /// each finds words the others miss (tirade, serendipity, déjà vu);
    /// candidates without an entry of their own in the dictionary are
    /// dropped, and a last pass reads each one's real definition and keeps
    /// those that match, best first.
    static func words(describedBy description: String) async -> [String] {
        guard isAvailable else { return [] }
        let request = "Description: \(description)"
        let format = "Answer with up to twelve words, best match first, separated by commas, and nothing else."
        async let precise = list(
            .described,
            "You are a reverse dictionary for writers. Given a description, list the precise words that dictionaries define this way, including rare, literary or technical words. Never invent phrases.",
            request, format: format
        )
        async let tipOfTongue = list(
            .described,
            "A writer has a word on the tip of their tongue. From their description, guess the single word they are thinking of, then other close candidates. Include words borrowed from other languages that English uses.",
            request, format: format
        )
        async let crossword = list(
            .described,
            "You are a crossword expert. Give the English words that a crossword clue with this definition would have as its answer.",
            request, format: format
        )
        let found = unique(await precise + tipOfTongue + crossword)
            .filter { $0.split(separator: " ").count <= 2 }
            .filter(DictionaryLookup.hasOwnEntry)
        let defined = found.prefix(24).compactMap { word in
            DictionaryLookup.firstDefinition(of: word).map { (word: word, definition: $0.text) }
        }
        guard defined.count > 1 else { return defined.map(\.word) }
        let list = defined.enumerated().map { "\($0.offset + 1). \($0.element.word): \($0.element.definition)" }.joined(separator: "\n")
        guard let answer = await ask(
            "You check which dictionary definitions match a description a writer gave.",
            "Description: \(description)\nCandidates:\n\(list)\n"
                + "Answer with the numbers of the candidates whose definition matches, best first, at most six, separated by commas, and nothing else."
        ) else { return defined.map(\.word) }
        let ranked = unique(numbers(answer).compactMap { defined.indices.contains($0 - 1) ? defined[$0 - 1].word : nil })
        return ranked.isEmpty ? defined.map(\.word) : ranked
    }

    /// One sentence on how two similar words differ in meaning, tone or
    /// use, given their definitions ("famous implies positive recognition;
    /// notorious implies negative reputation").
    static func difference(between first: String, _ firstDefinition: String?, and second: String, _ secondDefinition: String?) async -> String? {
        await ask(
            "You explain to a writer how two similar words differ. Answer in one plain sentence of at most 25 words, about meaning, tone or typical use. No preamble.",
            "\(first): \(firstDefinition ?? "")\n\(second): \(secondDefinition ?? "")\nHow do \(first) and \(second) differ?"
        )
    }

    /// Common phrases with `word` ("tough decision", "smile warmly"),
    /// as in a collocations dictionary, most common first.
    static func collocations(for word: String, partOfSpeech: String?) async -> [String] {
        let proposed = await list(
            .collocations,
            "You list collocations for writers: the words that naturally go with a given word, as in a collocations dictionary. Prefer adjective and noun, verb and noun, or verb and adverb pairs; avoid prepositions.",
            "Word: \(word)" + (partOfSpeech.map { " (\($0))" } ?? ""),
            format: "Answer with ten short phrases of two or three words that contain the word, most common first, separated by commas, and nothing else."
        )
        // The model sometimes splits a compound ("rain fall"): drop a
        // phrase whose words, joined, are a word of their own.
        let phrases = usefulCollocations(proposed, word: word)
        let compounds = Database.ranks(of: phrases.map { $0.replacingOccurrences(of: " ", with: "") })
        return phrases.filter { compounds[$0.replacingOccurrences(of: " ", with: "")] == nil }
    }

    private static let functionWords: Set<String> = [
        "a", "an", "the", "of", "for", "to", "in", "on", "at", "by", "from", "with", "about", "against", "into", "over",
        "that", "this", "these", "those", "it", "its", "and", "or", "as", "is", "be",
    ]

    /// Keeps phrases that contain `word` as a word of its own and at least
    /// one partner that is not a function word: drops "rainstorm" and
    /// "evidence of", keeps "light rain" and "tough decision".
    static func usefulCollocations(_ phrases: [String], word: String) -> [String] {
        unique(phrases.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }).filter { phrase in
            let words = phrase.split(separator: " ").map(String.init)
            guard words.count >= 2, words.count <= 4, words.contains(word.lowercased()) else { return false }
            return words.contains { $0 != word.lowercased() && !functionWords.contains($0) }
        }
    }

    /// Three natural sentences that use `word` in the sense `definition`,
    /// keeping only those that contain the word or a form of it.
    static func examples(of word: String, partOfSpeech: String?, definition: String) async -> [String] {
        let sentences = await list(
            .examples,
            "You write example sentences for a dictionary: short, natural, everyday sentences that show how a word is used.",
            "Word: \(word)" + (partOfSpeech.map { " (\($0))" } ?? "") + "\nMeaning: \(definition)",
            format: "Answer with three sentences, one per line, and nothing else."
        )
        return sentences.filter { usesWord(word, in: $0) }.prefix(3).map { $0 }
    }

    /// Whether `sentence` contains `word` or an inflection of it: a token
    /// that starts with the word's stem ("ran" is listed separately by
    /// callers that need irregular forms).
    static func usesWord(_ word: String, in sentence: String) -> Bool {
        let stem = String(word.lowercased().prefix(max(3, word.count - 2)))
        return sentence.lowercased().split(whereSeparator: { !$0.isLetter }).contains { $0.hasPrefix(stem) }
    }

    /// A plain explanation of an idiom or phrase the dictionary lacks, with
    /// a note on its tone ("touch base: make brief contact; informal").
    static func explain(phrase: String, in sentence: String?) async -> String? {
        await ask(
            "You explain English idioms and phrases to a writer in one or two plain sentences, and say when a phrase is informal, dated or regional. No preamble.",
            "Phrase: \(phrase)" + (sentence.map { "\nUsed in: \($0)" } ?? "")
        )
    }

    /// What a passage-note rewrite should do to a sentence.
    enum Rewrite {
        case split, active

        var instruction: String {
            switch self {
            case .split: "Split this long sentence into two or three shorter sentences."
            case .active: "Rewrite this sentence in the active voice."
            }
        }
    }

    /// The sentence rewritten as asked, keeping its meaning and tone, or
    /// nil when nothing new comes back.
    static func rewrite(_ sentence: String, _ rewrite: Rewrite) async -> String? {
        guard let answer = await ask(
            "You are an editor. You change only what is asked, keep the writer's meaning, tone and wording where you can, and answer with the rewritten text only.",
            "\(rewrite.instruction)\nSentence: \(sentence)"
        ) else { return nil }
        let text = answer.trimmingCharacters(in: CharacterSet(charactersIn: " \n\"\u{201C}\u{201D}"))
        return text.isEmpty || text == sentence ? nil : text
    }

    /// Which of `definitions` (0-based) matches how `word` is used in
    /// `sentence`: "She runs a small bakery" -> "be in charge of; manage".
    static func senseIndex(of word: String, in sentence: String, definitions: [String]) async -> Int? {
        guard definitions.count > 1 else { return nil }
        let list = definitions.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let instructions = "You pick which dictionary definition of a word matches its use in a sentence."
        let prompt = "Sentence: \(sentence)\nWord: \(word)\nDefinitions:\n\(list)"
        var number: Int?
        #if canImport(FoundationModels)
        if #available(macOS 26, *) { number = await structured(SensePick.self, instructions, prompt)?.number }
        #endif
        if number == nil, let answer = await ask(instructions, prompt + "\nAnswer with the number of the matching definition and nothing else.") {
            number = numbers(answer).first
        }
        guard let number, definitions.indices.contains(number - 1) else { return nil }
        return number - 1
    }

    /// Up to three of `candidates` that give the word the requested tone in
    /// the sentence ("more vivid" for "walked": strode, marched). Words
    /// outside the list are kept only if they are in the word list.
    static func toneChoices(for word: String, in sentence: String?, tone: String, candidates: [String]) async -> [String] {
        guard !candidates.isEmpty else { return [] }
        let proposed = await list(
            .tone,
            "You help a writer change the tone of one word. Prefer words from the candidate list; add another word only when none fits. Keep the meaning of the sentence.",
            (sentence.map { "Sentence: \($0)\n" } ?? "") + "Word: \(word)\nTone: \(tone)\nCandidates: \(candidates.joined(separator: ", "))",
            format: "Answer with three words, best first, separated by commas, and nothing else."
        )
        let allowed = Dictionary(candidates.map { ($0.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
        let known = Database.ranks(of: proposed.filter { allowed[$0.lowercased()] == nil })
        return unique(proposed.compactMap { allowed[$0.lowercased()] ?? (known[$0.lowercased()] != nil ? $0.lowercased() : nil) })
            .filter { $0.lowercased() != word.lowercased() }
    }

    /// The rhymes that would make a strong, natural ending for the next
    /// line of a poem or song, given the meaning and mood of `line`.
    static func rhymes(for line: String, endingIn word: String, candidates: [String]) async -> [String] {
        guard candidates.count > 1 else { return [] }
        let words = await list(
            .lineRhymes,
            "You help a songwriter or poet choose a rhyme for the next line.",
            "Line: \(line)\nIt ends in: \(word)\nRhymes: \(candidates.joined(separator: ", "))",
            format: "Answer with the rhymes from the list that would make a strong, natural end for the next line, given the meaning and mood of this line, best first, separated by commas, and nothing else. Leave out any that would sound forced."
        )
        return pick(words, from: candidates)
    }

    // MARK: Plain-text requests and their parsing

    #if canImport(FoundationModels)
    @available(macOS 26, *)
    private static var model: SystemLanguageModel { SystemLanguageModel(guardrails: .permissiveContentTransformations) }
    #endif

    /// The kinds of word list the model is asked for, each with its own
    /// structured answer type.
    private enum ListKind { case fits, described, collocations, tone, lineRhymes, examples }

    /// A list answer: structured first, plain text under permissive
    /// guardrails if the structured request fails.
    private static func list(_ kind: ListKind, _ instructions: String, _ prompt: String, format: String) async -> [String] {
        guard isAvailable else { return [] }
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            let words: [String]? = switch kind {
            case .fits: await structured(Fits.self, instructions, prompt)?.words
            case .described: await structured(Described.self, instructions, prompt)?.words
            case .collocations: await structured(Collocations.self, instructions, prompt)?.phrases
            case .tone: await structured(ToneChoices.self, instructions, prompt)?.words
            case .lineRhymes: await structured(LineRhymes.self, instructions, prompt)?.words
            case .examples: await structured(ExampleSentences.self, instructions, prompt)?.sentences
            }
            if let words, !words.isEmpty { return words.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
        }
        #endif
        let answer = await ask(instructions, prompt + "\n" + format)
        return kind == .examples ? (answer.map(lines) ?? []) : (answer.map(listItems) ?? [])
    }

    #if canImport(FoundationModels)
    @available(macOS 26, *)
    private static func structured<T: Generable>(_ type: T.Type, _ instructions: String, _ prompt: String) async -> T? {
        try? await LanguageModelSession(instructions: instructions).respond(to: prompt, generating: type).content
    }
    #endif

    /// The model's plain-text answer, or nil when it is unavailable or the
    /// request fails.
    private static func ask(_ instructions: String, _ prompt: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(macOS 26, *), isAvailable {
            let session = LanguageModelSession(model: model, instructions: instructions)
            let answer = try? await session.respond(to: prompt).content.trimmingCharacters(in: .whitespacesAndNewlines)
            return answer?.isEmpty == false ? answer : nil
        }
        #endif
        return nil
    }

    /// The items of a plain list answer, one per comma or line, without
    /// numbering, bullets, quotes or a closing period: "1. *tirade*" ->
    /// "tirade".
    static func listItems(_ answer: String) -> [String] {
        answer.components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { item in
                var item = item.trimmingCharacters(in: .whitespaces)
                if let range = item.range(of: "^(\\d+[.)]|[-•*])\\s*", options: .regularExpression) { item.removeSubrange(range) }
                return item.trimmingCharacters(in: CharacterSet(charactersIn: " .\"'*_\u{201C}\u{201D}\u{2018}\u{2019}"))
            }
            .filter { !$0.isEmpty }
    }

    /// The lines of an answer, without numbering or bullets.
    static func lines(_ answer: String) -> [String] {
        answer.components(separatedBy: "\n").map { line in
            var line = line.trimmingCharacters(in: .whitespaces)
            if let range = line.range(of: "^(\\d+[.)]|[-•*])\\s*", options: .regularExpression) { line.removeSubrange(range) }
            return line.trimmingCharacters(in: CharacterSet(charactersIn: " \"\u{201C}\u{201D}"))
        }.filter { !$0.isEmpty }
    }

    /// The numbers in an answer, in order: "4, 5" -> [4, 5].
    static func numbers(_ answer: String) -> [Int] {
        answer.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
    }

    /// The proposed words that are in `candidates`, in the candidates'
    /// spelling and the proposal's order.
    private static func pick(_ proposed: [String], from candidates: [String]) -> [String] {
        let allowed = Dictionary(candidates.map { ($0.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
        return unique(proposed.compactMap { allowed[$0.lowercased()] })
    }

    private static func unique(_ words: [String]) -> [String] {
        var seen = Set<String>()
        return words.filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
}

#if canImport(FoundationModels)
@available(macOS 26, *)
@Generable
private struct Fits {
    @Guide(description: "Candidates that can replace the word in this sentence with the same meaning, best first. Leave out any that change the meaning.")
    var words: [String]
}

@available(macOS 26, *)
@Generable
private struct LineRhymes {
    @Guide(description: "Rhyming words from the list that would make a strong, natural ending for the next line, given the meaning and mood of this line. Best first. Leave out words that would sound forced.")
    var words: [String]
}

@available(macOS 26, *)
@Generable
private struct ToneChoices {
    @Guide(description: "Single words or short fixed phrases that can replace the word in the sentence with the requested tone, best first.", .count(3))
    var words: [String]
}

@available(macOS 26, *)
@Generable
private struct SensePick {
    @Guide(description: "The number of the definition that matches how the word is used in the sentence.")
    var number: Int
}

@available(macOS 26, *)
@Generable
private struct Collocations {
    @Guide(description: "Short phrases of two or three words that native writers commonly use with the word, most common first. Each phrase contains the word.", .count(10))
    var phrases: [String]
}

@available(macOS 26, *)
@Generable
private struct ExampleSentences {
    @Guide(description: "Short, natural sentences that use the word in the given meaning.", .count(3))
    var sentences: [String]
}

@available(macOS 26, *)
@Generable
private struct Described {
    @Guide(description: "English words that mean what the description says, best match first.", .count(12))
    var words: [String]
}
#endif
