import Foundation

/// How often the user has replaced each word with a synonym from the
/// popup, kept in UserDefaults. A word replaced again and again ("very",
/// "really") is a crutch the writer reaches for, which the popup and the
/// passage notes point out.
final class ReplacedWords {
    static let shared = ReplacedWords()

    /// Replaced this often, a word counts as a crutch.
    static let crutchCount = 3

    private(set) var counts: [String: Int]

    private static let key = "WordPop.replacedWords"

    private init() {
        counts = UserDefaults.standard.dictionary(forKey: Self.key) as? [String: Int] ?? [:]
    }

    func record(_ word: String) {
        let normalized = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return }
        counts[normalized, default: 0] += 1
        UserDefaults.standard.set(counts, forKey: Self.key)
    }

    /// The times `word` was replaced, when that makes it a crutch.
    func crutchCount(of word: String) -> Int? {
        counts[word.lowercased()].flatMap { $0 >= Self.crutchCount ? $0 : nil }
    }

    /// The crutch words used in `text` (or a form of them), most replaced
    /// first, with how often each was replaced.
    func crutches(in text: String) -> [(word: String, count: Int)] {
        counts.filter { $0.value >= Self.crutchCount && TextStats.occurrences(of: $0.key, in: text) > 0 }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map { ($0.key, $0.value) }
    }

    func clear() {
        counts = [:]
        UserDefaults.standard.removeObject(forKey: Self.key)
    }
}
