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

    /// The misspelled words of a passage, once each in order of use, with
    /// their suggestions; words the spell checker has no suggestion for
    /// (often names) are left out.
    static func typos(in text: String, limit: Int = 8) -> [(word: String, suggestions: [String])] {
        let checker = NSSpellChecker.shared
        let ns = text as NSString
        var found: [(word: String, suggestions: [String])] = []
        var start = 0
        while start < ns.length, found.count < limit {
            let range = checker.checkSpelling(
                of: text, startingAt: start, language: "en", wrap: false, inSpellDocumentWithTag: 0, wordCount: nil
            )
            guard range.location != NSNotFound, range.length > 0 else { break }
            start = NSMaxRange(range)
            let word = ns.substring(with: range)
            guard !found.contains(where: { $0.word.lowercased() == word.lowercased() }) else { continue }
            let suggestions = suggestions(for: word, limit: 3)
            if !suggestions.isEmpty { found.append((word, suggestions)) }
        }
        return found
    }

    /// `text` with every use of each misspelled word (the keys, matched
    /// as whole words, in any case) changed to its fix, in the same
    /// capitalization: "Recieved" -> "Received".
    static func applying(_ fixes: [String: String], to text: String) -> String {
        var result = text
        for (typo, fix) in fixes {
            guard let pattern = try? NSRegularExpression(
                pattern: "\\b\(NSRegularExpression.escapedPattern(for: typo))\\b", options: .caseInsensitive
            ) else { continue }
            let ns = result as NSString
            for match in pattern.matches(in: result, range: NSRange(location: 0, length: ns.length)).reversed() {
                let original = (result as NSString).substring(with: match.range)
                result = (result as NSString).replacingCharacters(in: match.range, with: TextReplacer.matchingCase(of: original, fix))
            }
        }
        return result
    }
}
