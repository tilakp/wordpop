import Foundation

/// Offline synonym lookup, built from the Open English WordNet: for each
/// word, its dominant sense's synset-mates plus (for adjectives) "similar to"
/// satellite words, grouped by part of speech and ranked by sense order.
/// Grouping by part of speech avoids mixing unrelated senses together (e.g.
/// "run" the verb vs. "run" the noun), which is what made naive
/// whole-entry synonym lists noisy.
enum SynonymStore {
    private static let table: [String: [String: [String]]] = {
        guard let url = Bundle.main.url(forResource: "synonyms", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [String: [String]]].self, from: data) else {
            return [:]
        }
        return decoded
    }()

    static func synonyms(for word: String, partOfSpeech: String?) -> [String] {
        guard let byPartOfSpeech = table[word.lowercased()] else { return [] }
        return PartOfSpeechGroup.pick(from: byPartOfSpeech, preferring: partOfSpeech)
    }
}
