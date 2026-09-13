import Foundation

/// Offline rhyme lookup, built from the CMU Pronouncing Dictionary: words
/// grouped by the phoneme sequence from their last stressed vowel to the
/// end, ranked by general-English frequency. Not part-of-speech-scoped,
/// since rhyming is about pronunciation, not meaning.
enum RhymeStore {
    private static let table: [String: [String]] = {
        guard let url = Bundle.main.url(forResource: "rhymes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return decoded
    }()

    static func rhymes(for word: String) -> [String] {
        table[word.lowercased()] ?? []
    }
}
