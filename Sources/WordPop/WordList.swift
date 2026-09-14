/// Type-ahead vocabulary for Quick Search: dictionary lemmas ordered by
/// frequency (see scripts/build_words.py), so completions come most
/// common first.
enum WordList {
    static func suggestions(for prefix: String, limit: Int) -> [String] {
        let needle = prefix.lowercased()
        guard !needle.isEmpty else { return [] }
        return Database.wordsWithPrefix(needle, limit: limit)
    }
}
