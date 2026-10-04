import AppKit

/// Spelling suggestions from the macOS spell checker, which works offline.
enum Spelling {
    /// Close words for a misspelled word, best first; empty when the word
    /// is spelled right. Case variants ("Pharaoh", "pharaoh") are merged,
    /// keeping the lowercase one.
    static func suggestions(for word: String, limit: Int = 6) -> [String] {
        let checker = NSSpellChecker.shared
        let length = (word as NSString).length
        guard length > 1, checker.checkSpelling(
            of: word, startingAt: 0, language: "en", wrap: false, inSpellDocumentWithTag: 0, wordCount: nil
        ).location != NSNotFound else { return [] }
        let guesses = checker.guesses(
            forWordRange: NSRange(location: 0, length: length), in: word, language: "en", inSpellDocumentWithTag: 0
        ) ?? []
        var unique: [String] = []
        for guess in guesses {
            if let index = unique.firstIndex(where: { $0.lowercased() == guess.lowercased() }) {
                if guess == guess.lowercased() { unique[index] = guess }
            } else {
                unique.append(guess)
            }
        }
        return Array(unique.prefix(limit))
    }
}
