import NaturalLanguage

/// Words and phrases that link a sentence to the one before it, grouped
/// by the job they do, and how to put one at the start of a sentence.
enum Transitions {
    static let groups: [(job: String, phrases: [String])] = [
        ("Add", ["Also", "In addition", "Moreover", "Furthermore", "Besides"]),
        ("Contrast", ["However", "But", "Even so", "Still", "Nevertheless", "On the other hand"]),
        ("Cause", ["So", "As a result", "Therefore", "Because of this", "Consequently"]),
        ("Example", ["For example", "For instance", "In particular", "Specifically"]),
        ("Sequence", ["First", "Next", "Then", "After that", "Finally", "Meanwhile"]),
        ("Emphasis", ["Indeed", "In fact", "Above all", "Clearly"]),
        ("Sum up", ["In short", "Overall", "In summary", "In the end"]),
    ]

    /// Short links that read better without a comma: "So we left."
    private static let withoutComma: Set<String> = ["But", "So", "Then"]

    /// The transition the sentence already starts with, if any, as written
    /// ("However" in "However, the plan failed.").
    static func leading(in sentence: String) -> String? {
        let all = groups.flatMap(\.phrases).sorted { $0.count > $1.count }
        return all.first { phrase in
            guard sentence.lowercased().hasPrefix(phrase.lowercased()) else { return false }
            let rest = sentence.dropFirst(phrase.count)
            return rest.hasPrefix(",") || withoutComma.contains(phrase) && rest.hasPrefix(" ")
        }
    }

    /// `sentence` starting with `transition`, in place of any transition
    /// it starts with: "The plan failed." -> "However, the plan failed."
    /// The old first word keeps its capital when it is "I", a name or an
    /// acronym.
    static func applying(_ transition: String, to sentence: String) -> String {
        var rest = Substring(sentence)
        if let old = leading(in: sentence) {
            rest = rest.dropFirst(old.count)
            if rest.hasPrefix(",") { rest = rest.dropFirst() }
            rest = rest.drop { $0 == " " }
        }
        let body = keepsCapital(String(rest)) ? String(rest) : rest.prefix(1).lowercased() + rest.dropFirst()
        return transition + (withoutComma.contains(transition) ? " " : ", ") + body
    }

    private static func keepsCapital(_ text: String) -> Bool {
        let firstWord = text.prefix { $0.isLetter || $0 == "'" || $0 == "\u{2019}" }
        if firstWord == "I" || firstWord.hasPrefix("I'") || firstWord.hasPrefix("I\u{2019}") { return true }
        if firstWord.count > 1, firstWord.dropFirst().contains(where: \.isUppercase) { return true }
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        let (tag, _) = tagger.tag(at: text.startIndex, unit: .word, scheme: .nameType)
        return [.personalName, .placeName, .organizationName].contains(tag)
    }
}
