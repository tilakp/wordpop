/// Shared helper for SynonymStore/AntonymStore: both datasets are grouped
/// by part of speech, keyed by the same labels DictionaryLookup extracts
/// from Apple's dictionary text ("noun", "verb", "adjective", "adverb").
enum PartOfSpeechGroup {
    /// Fixed priority order used when the part of speech NOAD reports isn't
    /// one of the four the dataset is grouped by (e.g. "determiner",
    /// "preposition", "exclamation") — picking `dictionary.values.first` in
    /// that case would be non-deterministic, since Swift's Dictionary
    /// iteration order varies per process (hash seed randomization), so the
    /// same word could show different synonyms on different launches.
    private static let priority = ["adjective", "noun", "verb", "adverb"]

    static func pick(from groups: [String: [String]], preferring partOfSpeech: String?) -> [String] {
        if let partOfSpeech, priority.contains(partOfSpeech) {
            return groups[partOfSpeech] ?? []
        }
        for candidate in priority {
            if let matched = groups[candidate] {
                return matched
            }
        }
        return []
    }
}
