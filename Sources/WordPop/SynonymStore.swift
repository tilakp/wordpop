/// Offline synonym lookup, built from the Open English WordNet topped up
/// with the Moby Thesaurus (see scripts/build_synonyms.py), grouped by part
/// of speech so "run" the verb and "run" the noun stay separate.
enum SynonymStore {
    static func synonyms(for word: String, partOfSpeech: String?) -> [String] {
        PartOfSpeechGroup.pick(from: Database.groups("synonyms", word: word), preferring: partOfSpeech)
    }
}
