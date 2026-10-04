import Foundation

/// Finds an idiom the user selected among the dictionary's phrase entries:
/// "kicked the bucket" is listed as "kick the bucket" under "kick", which
/// the lookup alone shows only as the verb.
enum PhraseMatch {
    /// Placeholders in phrase entries that stand for any word.
    private static let placeholders: Set<String> = ["one's", "ones", "one", "someone", "someone's", "something", "oneself", "somebody"]
    private static let stopWords: Set<String> = ["a", "an", "the", "of", "to", "in", "on", "at", "for", "and", "or", "with", "by"]
    /// Words in a selection that fill a "one's" placeholder.
    private static let possessives: Set<String> = ["my", "your", "his", "her", "its", "our", "their"]

    /// Whether a selection looks like a phrase worth matching: two to seven
    /// words that the lookup reduced to a single headword.
    static func isPhrase(_ selection: String, lookedUpAs headword: String) -> Bool {
        let count = tokens(selection).count
        return (2...7).contains(count) && tokens(headword).count < count
    }

    /// The phrase that best matches the selection, if one covers it well:
    /// every content word of the phrase must appear in the selection (by
    /// stem, so tenses match), and most of the selection must be covered.
    static func best(for selection: String, among phrases: [Phrase]) -> Phrase? {
        bestScored(for: selection, among: phrases)?.phrase
    }

    /// Every content word of the phrase must be in the selection, and at
    /// least three quarters of the selection's content words in the phrase
    /// ("on the move" does not cover "moved the goalposts").
    private static func bestScored(for selection: String, among phrases: [Phrase]) -> (phrase: Phrase, score: Double)? {
        let selected = tokens(selection)
        let selectedContent = selected.filter { !stopWords.contains($0) && !possessives.contains($0) }.map(stem)
        guard selected.count >= 2, !selectedContent.isEmpty else { return nil }
        var best: (phrase: Phrase, score: Double)?
        for phrase in phrases {
            let words = tokens(phrase.phrase).filter { !placeholders.contains($0) }
            let content = words.filter { !stopWords.contains($0) }.map(stem)
            guard !content.isEmpty, content.allSatisfy({ word in selectedContent.contains { matches($0, word) } }) else { continue }
            let covered = Double(selectedContent.filter { token in content.contains { matches(token, $0) } }.count)
                / Double(selectedContent.count)
            guard covered >= 0.75 else { continue }
            let score = covered + Double(content.count) / 10
            if score > (best?.score ?? 0) { best = (phrase, score) }
        }
        return best
    }

    /// The matching phrase entry and the headword it is listed under,
    /// searching the looked-up entry first and then the entries of the
    /// selection's other content words ("move the goalposts" is under
    /// "goalpost").
    static func find(_ selection: String, in entry: WordEntry, lookup: (String) -> WordEntry) -> (phrase: Phrase, source: String)? {
        var best = bestScored(for: selection, among: entry.phrases).map { (phrase: $0.phrase, source: entry.word, score: $0.score) }
        let words = tokens(selection).filter { $0.count >= 3 && !stopWords.contains($0) && !placeholders.contains($0) && !possessives.contains($0) }
        for word in words where word != entry.word.lowercased() {
            let other = lookup(word)
            if let match = bestScored(for: selection, among: other.phrases), match.score > (best?.score ?? 0) {
                best = (match.phrase, other.word, match.score)
            }
        }
        return best.map { ($0.phrase, $0.source) }
    }

    private static func tokens(_ text: String) -> [String] {
        text.lowercased().split(whereSeparator: { !$0.isLetter && $0 != "'" }).map(String.init)
    }

    /// The first four letters, enough to match kick and kicked, beans and
    /// bean, without merging unrelated short words.
    private static func stem(_ word: String) -> String { String(word.prefix(4)) }

    /// Stems match when one starts with the other, so the irregular "bit"
    /// matches "bite"; pronouns are left to `possessives`.
    private static func matches(_ a: String, _ b: String) -> Bool {
        a == b || (min(a.count, b.count) >= 3 && (a.hasPrefix(b) || b.hasPrefix(a)))
    }
}
