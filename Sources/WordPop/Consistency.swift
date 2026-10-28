import AppKit

/// Things a passage does two ways, which an editor would make the same:
/// one word spelled two ways ("email" and "e-mail"), British and American
/// spelling together, straight and curly quotes, one and two spaces after
/// a sentence, and acronyms used before they are spelled out.
struct Consistency: Equatable {
    /// Each word the passage spells more than one way, most used first.
    var variants: [[String]] = []
    /// British-only and American-only spellings, when the passage has
    /// both, with the other spelling of each where the checker knows it.
    var british: [String] = []
    var american: [String] = []
    var toAmerican: [String: String] = [:]
    var toBritish: [String: String] = [:]
    var mixedQuotes = false
    var mixedSpacing = false
    /// Acronyms with no "(ABC)" before or at their first use.
    var acronyms: [String] = []

    var isEmpty: Bool { self == Consistency() }

    static func check(_ text: String) -> Consistency {
        var result = Consistency()
        let tokens = words(in: text)
        result.variants = variants(in: tokens)
        let (british, american) = spellingSystems(of: tokens)
        if !british.isEmpty, !american.isEmpty {
            result.british = british
            result.american = american
            result.toAmerican = counterparts(of: british, from: "en_GB", to: "en_US")
            result.toBritish = counterparts(of: american, from: "en_US", to: "en_GB")
        }
        result.mixedQuotes = text.contains { "\"'".contains($0) } && text.contains { "\u{201C}\u{201D}\u{2018}\u{2019}".contains($0) }
        result.mixedSpacing = text.range(of: "[.!?][\"\u{201D}]? {2,}[A-Z]", options: .regularExpression) != nil
            && text.range(of: "[.!?][\"\u{201D}]? [A-Z]", options: .regularExpression) != nil
        result.acronyms = undefinedAcronyms(in: text)
        return result
    }

    /// Word tokens in order, keeping hyphens and apostrophes inside words.
    private static func words(in text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "[\\p{L}]+(?:[-'\u{2019}][\\p{L}]+)*")
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
    }

    /// Words written both with a hyphen and as one word: "e-mail" and
    /// "email", "co-operate" and "cooperate". Two words against one
    /// ("every day", "everyday") or a hyphen against a space ("well-known
    /// author", "is well known") are often both right, so they are not
    /// compared.
    static func variants(in tokens: [String]) -> [[String]] {
        var counts: [String: Int] = [:]
        var spelling: [String: String] = [:]
        for token in tokens {
            counts[token.lowercased(), default: 0] += 1
            if spelling[token.lowercased()] == nil { spelling[token.lowercased()] = token }
        }
        return counts.keys.filter { $0.contains("-") }
            .compactMap { hyphenated -> [String]? in
                let joined = hyphenated.replacingOccurrences(of: "-", with: "")
                guard counts[joined] != nil else { return nil }
                return [hyphenated, joined].sorted { counts[$0]! != counts[$1]! ? counts[$0]! > counts[$1]! : $0 > $1 }.map { spelling[$0]! }
            }
            .sorted { $0[0].lowercased() < $1[0].lowercased() }
    }

    /// The words only the British or only the American spell checker
    /// accepts ("colour", "organised"; "color", "organized"), once each.
    private static func spellingSystems(of tokens: [String]) -> (british: [String], american: [String]) {
        var british: [String] = [], american: [String] = []
        var seen = Set<String>()
        for token in tokens where token.count >= 4 && !token.contains("-") && seen.insert(token.lowercased()).inserted {
            let gb = isSpelledRight(token, in: "en_GB"), us = isSpelledRight(token, in: "en_US")
            if gb, !us { british.append(token) }
            if us, !gb { american.append(token) }
        }
        return (british, american)
    }

    /// The other locale's spelling of each word: its first suggestion
    /// there that starts with the same two letters, in the same case, and
    /// that the word's own locale rejects or that is at most two edits
    /// away ("center" -> "centre"). So "gray" does not become "tray", nor
    /// "enrol" "Enron".
    private static func counterparts(of words: [String], from source: String, to target: String) -> [String: String] {
        var result: [String: String] = [:]
        for word in words {
            let guesses = NSSpellChecker.shared.guesses(
                forWordRange: NSRange(location: 0, length: (word as NSString).length), in: word, language: target, inSpellDocumentWithTag: 0
            ) ?? []
            if let guess = guesses.first(where: { guess in
                guess.prefix(2) == word.prefix(2) && (!isSpelledRight(guess, in: source) || editDistance(guess, word) <= 2)
            }) {
                result[word] = guess
            }
        }
        return result
    }

    static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty, !b.isEmpty else { return max(a.count, b.count) }
        var row = Array(0...b.count)
        for i in 1...a.count {
            var diagonal = row[0]
            row[0] = i
            for j in 1...b.count {
                let above = row[j]
                row[j] = min(above + 1, row[j - 1] + 1, diagonal + (a[i - 1] == b[j - 1] ? 0 : 1))
                diagonal = above
            }
        }
        return row[b.count]
    }

    private static func isSpelledRight(_ word: String, in language: String) -> Bool {
        NSSpellChecker.shared.checkSpelling(
            of: word, startingAt: 0, language: language, wrap: false, inSpellDocumentWithTag: 0, wordCount: nil
        ).location == NSNotFound
    }

    /// Acronyms everyone knows, which need no spelling out.
    private static let commonAcronyms: Set<String> = [
        "AI", "AM", "API", "ASAP", "BBC", "CEO", "CFO", "COO", "CPU", "CSS", "CTO", "DIY", "DNA", "EU", "FAQ", "FBI", "FYI",
        "GPS", "HR", "HTML", "HTTP", "HTTPS", "ID", "IQ", "IT", "JSON", "NASA", "NATO", "OK", "PC", "PDF", "PM", "PR", "PS",
        "RSVP", "SMS", "SQL", "TV", "UI", "UK", "UN", "URL", "USA", "US", "USB", "UX", "VIP", "XML", "II", "III", "IV", "VI",
        "VII", "VIII", "IX", "XI", "XII",
    ]

    /// Capitalized words of two to six letters that are not common words
    /// in capitals ("NOT") and have no "(ABC)" before or at their first
    /// use, as "Simplified Technical English (STE)" gives one.
    static func undefinedAcronyms(in text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "\\b[A-Z]{2,6}s?\\b")
        let ns = text as NSString
        var found: [String] = []
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            var acronym = ns.substring(with: match.range)
            if acronym.hasSuffix("s") { acronym.removeLast() }
            guard !found.contains(acronym), !commonAcronyms.contains(acronym), isAcronym(acronym) else { continue }
            let firstUse = ns.range(of: acronym).location
            let definition = ns.range(of: "(\(acronym))")
            if definition.location == NSNotFound || definition.location > firstUse + 1 { found.append(acronym) }
        }
        return found
    }

    /// Whether a run of capitals is an acronym, not a word in capitals for
    /// emphasis or a heading ("NOT", "WARNING").
    private static func isAcronym(_ word: String) -> Bool {
        !isSpelledRight(word.lowercased(), in: "en")
    }
}
