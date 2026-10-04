import Foundation

/// Matches a synonym to the word form of the selection it replaces:
/// replacing "ran" with "sprint" gives "sprinted", "children" with "kid"
/// gives "kids". Irregular forms come from the dictionary's own list
/// ("past ran", "past participle torn"); regular ones from spelling rules.
enum Inflection {
    enum Form: Equatable {
        case plain, s, ing, past, pastParticiple, comparative, superlative
    }

    /// The forms a dictionary entry lists, by kind.
    struct Listed: Equatable {
        var s: String?, ing: String?, past: String?, pastParticiple: String?, comparative: String?, superlative: String?

        func value(for form: Form) -> String? {
            switch form {
            case .plain: nil
            case .s: s
            case .ing: ing
            case .past: past
            case .pastParticiple: pastParticiple ?? past
            case .comparative: comparative
            case .superlative: superlative
            }
        }
    }

    /// Reads the entry's form list: "runs", "running", "past ran", "past
    /// participle run", "third singular present goes", "plural mice",
    /// "bigger". Unlabelled forms are told apart by their ending.
    static func listed(_ forms: [String]) -> Listed {
        var listed = Listed()
        let labels: [(String, [WritableKeyPath<Listed, String?>])] = [
            ("third singular present ", [\.s]), ("third person singular present ", [\.s]), ("plural ", [\.s]),
            ("present participle ", [\.ing]), ("past and past participle ", [\.past, \.pastParticiple]),
            ("past participle ", [\.pastParticiple]), ("past ", [\.past]),
            ("comparative ", [\.comparative]), ("superlative ", [\.superlative]),
        ]
        for raw in forms {
            let item = raw.lowercased()
            var paths: [WritableKeyPath<Listed, String?>] = []
            var value = item
            if let (label, labelPaths) = labels.first(where: { item.hasPrefix($0.0) }) {
                paths = labelPaths
                value = String(item.dropFirst(label.count))
            } else if item.hasSuffix("ing") {
                paths = [\.ing]
            } else if item.hasSuffix("est") {
                paths = [\.superlative]
            } else if item.hasSuffix("er") {
                paths = [\.comparative]
            } else if item.hasSuffix("ed") {
                paths = [\.past]
            } else if item.hasSuffix("s") {
                paths = [\.s]
            }
            // "burned or burnt": the first spelling is the common one.
            value = value.components(separatedBy: " or ")[0].trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty, !value.contains(" ") else { continue }
            for path in paths where listed[keyPath: path] == nil { listed[keyPath: path] = value }
        }
        return listed
    }

    /// Which form of `lemma` the token is; `.plain` when it is the lemma
    /// itself or the form cannot be told.
    static func form(of token: String, lemma: String, forms: [String]) -> Form {
        let token = token.lowercased(), lemma = lemma.lowercased()
        guard token != lemma else { return .plain }
        let listed = listed(forms)
        for form in [Form.past, .pastParticiple, .ing, .s, .comparative, .superlative] where listed.value(for: form) == token {
            return form
        }
        for form in [Form.ing, .past, .s, .comparative, .superlative] where regular(lemma, form) == token {
            return form
        }
        return .plain
    }

    /// `word` in the given form. For a phrase ("make off") the first word
    /// is inflected; `formsOf` gives a word's dictionary form list.
    static func inflect(_ word: String, as form: Form, formsOf: (String) -> [String]) -> String {
        guard form != .plain else { return word }
        var parts = word.split(separator: " ", maxSplits: 1).map(String.init)
        guard let head = parts.first else { return word }
        if parts.count > 1, form == .comparative || form == .superlative {
            return (form == .comparative ? "more " : "most ") + word
        }
        parts[0] = listed(formsOf(head)).value(for: form) ?? regular(head, form)
        return parts.joined(separator: " ")
    }

    /// The regular spelling: walks, walking, walked, bigger, biggest,
    /// hurries, hurried, more careful.
    static func regular(_ word: String, _ form: Form) -> String {
        let w = word.lowercased()
        let endsConsonantY = w.count > 1 && w.hasSuffix("y") && !isVowel(w.dropLast().last!)
        switch form {
        case .plain:
            return w
        case .s:
            if ["s", "x", "z", "ch", "sh"].contains(where: w.hasSuffix) { return w + "es" }
            return endsConsonantY ? w.dropLast() + "ies" : w + "s"
        case .ing:
            if w.hasSuffix("ie") { return w.dropLast(2) + "ying" }
            if w.hasSuffix("e"), !["ee", "oe", "ye"].contains(where: w.hasSuffix) { return w.dropLast() + "ing" }
            return (doublesFinalConsonant(w) ? w + String(w.last!) : w) + "ing"
        case .past, .pastParticiple:
            if w.hasSuffix("e") { return w + "d" }
            if endsConsonantY { return w.dropLast() + "ied" }
            return (doublesFinalConsonant(w) ? w + String(w.last!) : w) + "ed"
        case .comparative, .superlative:
            let ending = form == .comparative ? "er" : "est"
            let syllables = syllableCount(w)
            if syllables >= 3 || (syllables == 2 && !w.hasSuffix("y")) { return (form == .comparative ? "more " : "most ") + w }
            if w.hasSuffix("e") { return w + ending.dropFirst() }
            if endsConsonantY { return w.dropLast() + "i" + ending }
            return (doublesFinalConsonant(w) ? w + String(w.last!) : w) + ending
        }
    }

    /// One-syllable words ending consonant, vowel, consonant double the
    /// last letter (stop -> stopping); longer ones are listed by the
    /// dictionary when they do (refer -> referring).
    private static func doublesFinalConsonant(_ w: String) -> Bool {
        let letters = Array(w)
        guard letters.count >= 3, syllableCount(w) == 1 else { return false }
        let (a, b, c) = (letters[letters.count - 3], letters[letters.count - 2], letters[letters.count - 1])
        return !isVowel(a) && isVowel(b) && !isVowel(c) && !"wxy".contains(c)
    }

    private static func syllableCount(_ w: String) -> Int {
        var count = 0, previousWasVowel = false
        for character in w {
            let vowel = isVowel(character) || character == "y"
            if vowel && !previousWasVowel { count += 1 }
            previousWasVowel = vowel
        }
        if w.hasSuffix("e"), !w.hasSuffix("le"), count > 1 { count -= 1 }
        return max(count, 1)
    }

    private static func isVowel(_ character: Character) -> Bool { "aeiou".contains(character) }
}
