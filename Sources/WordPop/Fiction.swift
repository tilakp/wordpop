import Foundation

/// Notes for fiction, as ProWritingAid and AutoCrit give them: adverbs on
/// dialogue tags ("she said angrily"), tags other than "said" and "asked"
/// ("he hissed"), filter words ("she saw the door open") and emotions
/// told rather than shown ("he felt angry"), with the share of the words
/// that is dialogue. All rule-based; none of it is wrong as such, so the
/// popup only lists it.
struct FictionNotes: Equatable {
    /// Share of the words inside quotes, 0 to 1; nil when there is no
    /// dialogue.
    var dialogueShare: Double?
    var tagAdverbs: [String] = []
    var showyTags: [Count] = []
    var filterWords: [Count] = []
    var emotionTells: [String] = []

    struct Count: Equatable {
        let word: String
        let count: Int
    }

    var isEmpty: Bool { tagAdverbs.isEmpty && showyTags.isEmpty && filterWords.isEmpty && emotionTells.isEmpty && dialogueShare == nil }

    static func check(_ text: String) -> FictionNotes {
        var notes = FictionNotes()
        let ns = text as NSString
        let all = NSRange(location: 0, length: ns.length)
        let quotes = quotePattern.matches(in: text, range: all).map(\.range)
        let total = wordCount(text)
        if !quotes.isEmpty, total > 0 {
            notes.dialogueShare = Double(quotes.reduce(0) { $0 + wordCount(ns.substring(with: $1)) }) / Double(total)
        }

        // The words just after each closing quote and just before each
        // opening one hold the tag: '"Go," she said quietly.' or 'She
        // said quietly, "Go."' A tag between two quotes is counted once.
        let tokens = wordPattern.matches(in: text, range: all).map { (word: ns.substring(with: $0.range).lowercased(), range: $0.range) }
        var tagCounts: [String: Int] = [:]
        var seen = Set<Int>()
        for quote in quotes {
            let after = tokens.indices.filter { tokens[$0].range.location >= NSMaxRange(quote) && tokens[$0].range.location < NSMaxRange(quote) + 60 }.prefix(4)
            let before = tokens.indices.filter { NSMaxRange(tokens[$0].range) <= quote.location && NSMaxRange(tokens[$0].range) > quote.location - 60 }.suffix(4)
            for window in [Array(after), Array(before)] {
                guard let index = window.first(where: { tagVerbs.contains(tokens[$0].word) || showyTagVerbs.contains(tokens[$0].word) }),
                      seen.insert(index).inserted else { continue }
                let tag = tokens[index].word
                if showyTagVerbs.contains(tag) { tagCounts[tag, default: 0] += 1 }
                let neighbors = [index - 1, index + 1].filter(window.contains).map { tokens[$0].word }
                if let adverb = neighbors.first(where: { $0.hasSuffix("ly") && $0.count > 4 && !notAdverbs.contains($0) }) {
                    let phrase = "\(tag) \(adverb)"
                    if !notes.tagAdverbs.contains(phrase) { notes.tagAdverbs.append(phrase) }
                }
            }
        }
        notes.showyTags = sorted(tagCounts)

        var filterCounts: [String: Int] = [:]
        for token in tokens where filterWords.contains(token.word) { filterCounts[token.word, default: 0] += 1 }
        notes.filterWords = sorted(filterCounts)

        for match in emotionPattern.matches(in: text, range: all) {
            let phrase = ns.substring(with: match.range).lowercased()
            if !notes.emotionTells.contains(phrase) { notes.emotionTells.append(phrase) }
        }
        return notes
    }

    private static func sorted(_ counts: [String: Int]) -> [Count] {
        counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map { Count(word: $0.key, count: $0.value) }
    }

    private static let wordPattern = try! NSRegularExpression(pattern: "[\\p{L}]+(?:['\u{2019}][\\p{L}]+)*")

    private static func wordCount(_ text: String) -> Int { text.split(whereSeparator: \.isWhitespace).count }

    /// "…" or “…”, on one line.
    private static let quotePattern = try! NSRegularExpression(pattern: "\"[^\"\\n]+\"|\u{201C}[^\u{201D}\\n]+\u{201D}")

    private static let tagVerbs: Set<String> = ["said", "says", "say", "asked", "asks", "ask"]

    private static let showyTagVerbs: Set<String> = [
        "hissed", "growled", "exclaimed", "snapped", "barked", "snarled", "sneered", "spat", "roared", "bellowed", "shrieked",
        "screamed", "yelled", "shouted", "cried", "wailed", "moaned", "groaned", "whimpered", "sobbed", "purred", "cooed",
        "chirped", "giggled", "chuckled", "laughed", "snorted", "huffed", "sighed", "breathed", "gasped", "smiled", "grinned",
        "smirked", "retorted", "quipped", "interjected", "opined", "intoned", "declared", "announced", "demanded", "insisted",
        "pleaded", "begged", "stammered", "stuttered", "muttered", "mumbled", "murmured", "whispered", "mused", "queried",
        "inquired", "enquired", "responded", "replied", "admonished", "scolded", "ventured", "volunteered", "blurted",
    ]

    /// -ly words that are not adverbs.
    private static let notAdverbs: Set<String> = ["only", "early", "family", "holly", "reply", "supply", "fly", "lovely", "lonely", "friendly", "silly", "ugly"]

    private static let filterWords: Set<String> = [
        "saw", "see", "sees", "seeing", "heard", "hear", "hears", "hearing", "felt", "feel", "feels", "noticed", "notice",
        "notices", "realized", "realised", "realize", "realise", "realizes", "realises", "wondered", "wonder", "wonders",
        "watched", "watches", "decided", "decides", "seemed", "seems", "knew",
    ]

    private static let emotions = [
        "angry", "sad", "happy", "nervous", "afraid", "scared", "frightened", "terrified", "anxious", "worried", "excited",
        "jealous", "embarrassed", "ashamed", "guilty", "lonely", "bored", "confused", "frustrated", "annoyed", "furious",
        "upset", "hurt", "relieved", "surprised", "shocked", "disappointed", "hopeful", "proud", "calm", "tense", "uneasy",
        "uncomfortable", "overwhelmed", "devastated", "heartbroken", "elated", "thrilled", "content", "miserable",
        "desperate", "helpless", "hopeless", "resentful", "bitter", "irritated", "delighted", "grateful", "curious",
        "suspicious", "horrified", "disgusted", "panicked", "restless", "shy", "insecure", "determined", "defeated",
        "humiliated", "envious", "ecstatic", "glum", "gloomy", "enraged", "livid", "joyful", "sorry", "fearful",
    ]
    private static let feelings = ["anger", "fear", "joy", "dread", "rage", "sadness", "grief", "pride", "shame", "guilt", "hope", "relief", "panic", "despair", "envy", "jealousy"]

    /// "felt angry", "was very nervous", "filled with dread", "a wave of
    /// panic".
    private static let emotionPattern = try! NSRegularExpression(
        pattern: "\\b(?:(?:felt|feel|feels|feeling|was|were|seemed|looked|became|grew)\\s+(?:very\\s+|so\\s+|really\\s+|quite\\s+|a bit\\s+)?(?:"
            + emotions.joined(separator: "|") + ")|(?:filled|overcome|consumed|gripped)\\s+(?:with|by)\\s+(?:"
            + feelings.joined(separator: "|") + ")|(?:a|an)\\s+(?:wave|surge|pang|rush|flood|stab)\\s+of\\s+(?:"
            + feelings.joined(separator: "|") + "))\\b",
        options: .caseInsensitive
    )
}
