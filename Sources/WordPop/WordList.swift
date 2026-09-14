import Foundation

/// Type-ahead vocabulary for Quick Search: single-word dictionary lemmas
/// ordered by frequency, so a linear prefix scan yields the most common
/// completions first.
enum WordList {
    private static let words: [String] = {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").map(String.init)
    }()

    static func suggestions(for prefix: String, limit: Int) -> [String] {
        let needle = prefix.lowercased()
        guard !needle.isEmpty else { return [] }
        var result: [String] = []
        for word in words where word.hasPrefix(needle) {
            result.append(word)
            if result.count == limit { break }
        }
        return result
    }

    static func warmUp() {
        _ = words.count
    }
}
