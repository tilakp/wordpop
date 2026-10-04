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

#endif
