import Foundation

/// Offline antonym lookup, built the same way as SynonymStore: from the
/// Open English WordNet's direct per-sense antonym relation, grouped by
/// part of speech.
enum AntonymStore {
    private static let table: [String: [String: [String]]] = {
        guard let url = Bundle.main.url(forResource: "antonyms", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [String: [String]]].self, from: data) else {
            return [:]
        }
        return decoded
    }()

    static func antonyms(for word: String, partOfSpeech: String?) -> [String] {
        guard let byPartOfSpeech = table[word.lowercased()] else { return [] }
        return PartOfSpeechGroup.pick(from: byPartOfSpeech, preferring: partOfSpeech)
    }
}
