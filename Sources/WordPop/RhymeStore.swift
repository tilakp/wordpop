/// Offline rhyme lookup, built from the CMU Pronouncing Dictionary (see
/// scripts/build_rhymes.py). Not part-of-speech-scoped, since rhyming is
/// about pronunciation, not meaning.
enum RhymeStore {
    static func rhymes(for word: String) -> [String] {
        Database.list("rhymes", word: word)
    }
}
