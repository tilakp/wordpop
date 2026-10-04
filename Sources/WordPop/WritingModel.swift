import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Writing help from Apple's on-device language model (macOS 26 or later
/// with Apple Intelligence turned on). It runs locally, so nothing leaves
/// the Mac. Where the model is missing, every call returns no results and
/// the popup and Quick Search behave as before.
enum WritingModel {
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// The candidates that can replace `word` in `sentence` without
    /// changing its meaning, best first. Only words from `candidates` come
    /// back: the model sometimes adds the word itself or new words.
    static func bestFits(for word: String, in sentence: String, candidates: [String]) async -> [String] {
        #if canImport(FoundationModels)
        if #available(macOS 26, *), isAvailable, !candidates.isEmpty {
            let session = LanguageModelSession(instructions: """
                You help a writer choose a synonym. Judge each candidate only by whether it can replace the word \
                in the given sentence without changing its meaning or sounding wrong.
                """)
            let prompt = "Sentence: \(sentence)\nWord: \(word)\nCandidates: \(candidates.joined(separator: ", "))"
            guard let response = try? await session.respond(to: prompt, generating: Fits.self) else { return [] }
            let allowed = Dictionary(candidates.map { ($0.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
            return unique(response.content.words.compactMap { allowed[$0.lowercased()] })
        }
        #endif
        return []
    }

    /// Words that match a description ("the smell of rain on dry earth" ->
    /// petrichor), keeping only those with an entry of their own in the
    /// dictionary, which drops phrases the model makes up.
    static func words(describedBy description: String) async -> [String] {
        #if canImport(FoundationModels)
        if #available(macOS 26, *), isAvailable {
            let session = LanguageModelSession(instructions: """
                You are a reverse dictionary for writers. Given a description, list the precise words that dictionaries \
                define this way, including rare, literary or technical words. Never invent phrases. For example, \
                "a strong desire to travel" gives wanderlust and "a word that imitates a sound" gives onomatopoeia.
                """)
            guard let response = try? await session.respond(to: "Description: \(description)", generating: Described.self) else { return [] }
            return unique(response.content.words.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
                .filter(DictionaryLookup.hasOwnEntry)
        }
        #endif
        return []
    }

    /// One sentence on how two similar words differ in meaning, tone or
    /// use, given their definitions ("famous implies positive recognition;
    /// notorious implies negative reputation").
    static func difference(between first: String, _ firstDefinition: String?, and second: String, _ secondDefinition: String?) async -> String? {
        #if canImport(FoundationModels)
        if #available(macOS 26, *), isAvailable {
            let session = LanguageModelSession(instructions: """
                You explain to a writer how two similar words differ. Answer in one plain sentence of at most 25 words, \
                about meaning, tone or typical use. No preamble.
                """)
            let prompt = "\(first): \(firstDefinition ?? "")\n\(second): \(secondDefinition ?? "")\nHow do \(first) and \(second) differ?"
            let answer = try? await session.respond(to: prompt).content.trimmingCharacters(in: .whitespacesAndNewlines)
            return answer?.isEmpty == false ? answer : nil
        }
        #endif
        return nil
    }

    /// Common phrases with `word` ("tough decision", "smile warmly"),
    /// as in a collocations dictionary, most common first.
    static func collocations(for word: String, partOfSpeech: String?) async -> [String] {
        #if canImport(FoundationModels)
        if #available(macOS 26, *), isAvailable {
            let session = LanguageModelSession(instructions: """
                You list collocations for writers: the words that naturally go with a given word, as in a collocations \
                dictionary. Prefer adjective and noun, verb and noun, or verb and adverb pairs; avoid prepositions.
                """)
            let prompt = "Word: \(word)" + (partOfSpeech.map { " (\($0))" } ?? "")
            guard let response = try? await session.respond(to: prompt, generating: Collocations.self) else { return [] }
            // The model sometimes splits a compound ("rain fall"): drop a
            // phrase whose words, joined, are a word of their own.
            let phrases = usefulCollocations(response.content.phrases, word: word)
            let compounds = Database.ranks(of: phrases.map { $0.replacingOccurrences(of: " ", with: "") })
            return phrases.filter { compounds[$0.replacingOccurrences(of: " ", with: "")] == nil }
        }
        #endif
        return []
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
private struct Collocations {
    @Guide(description: "Short phrases of two or three words that native writers commonly use with the word, most common first. Each phrase contains the word.", .count(10))
    var phrases: [String]
}

@available(macOS 26, *)
@Generable
private struct Described {
    @Guide(description: "Precise English words that mean what the description says, best match first.", .count(10))
    var words: [String]
}
#endif
