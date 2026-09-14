/// Offline rhyme lookup, built from the CMU Pronouncing Dictionary (see
/// scripts/build_rhymes.py). Not part-of-speech-scoped, since rhyming is
/// about pronunciation, not meaning.
enum RhymeStore {
    static func rhymes(for word: String) -> [String] {
        Database.list("rhymes", word: word)
    }

    /// Slant rhymes (matching vowels, consonants one edit apart) for words
    /// with few perfect rhymes: "orange" -> storage, porridge.
    static func nearRhymes(for word: String) -> [String] {
        Database.list("near_rhymes", word: word)
    }
}
