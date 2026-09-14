/// Offline antonym lookup from the Open English WordNet's antonym relation,
/// grouped by part of speech like SynonymStore.
enum AntonymStore {
    static func antonyms(for word: String, partOfSpeech: String?) -> [String] {
        PartOfSpeechGroup.pick(from: Database.groups("antonyms", word: word), preferring: partOfSpeech)
    }
}
