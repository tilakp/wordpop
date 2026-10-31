/// Short guides behind the notes on a passage: why each kind of note
/// matters and what to do about it, with an example. Keyed by the
/// section's title as the notes show it (before "Above grade" takes its
/// number).
enum Guides {
    static func text(for title: String) -> String? {
        let key = title.hasPrefix("Above grade") ? "Above grade" : title.hasPrefix("Long sentences") ? "Long sentences" : title
        return guides[key]
    }

    private static let guides: [String: String] = [
        "Spelling": "Words the macOS spell checker does not know, with its best guesses. A name or a term is often not a typo: click Not a typo to teach it to your Mac.",
        "Grammar": "Mistakes the macOS grammar checker finds, such as \u{201C}a apple\u{201D} or \u{201C}should of\u{201D}. It misses many mistakes, so no note does not mean no mistake.",
        "Consistency": "Things the text does two ways. Readers notice \u{201C}email\u{201D} next to \u{201C}e-mail\u{201D}, or \u{201C}colour\u{201D} next to \u{201C}center\u{201D}. Pick one and use it throughout.",
        "Style rules": "What breaks your style rules or the preset you chose in Preferences. Edit My Rules in Preferences opens your own list.",
        "Wordy phrases and clich\u{E9}s": "Phrases that take more words than they need (\u{201C}in order to\u{201D} \u{2192} to), formal words with a plain one (\u{201C}utilize\u{201D} \u{2192} use), hidden verbs (\u{201C}made a decision\u{201D} \u{2192} decided), and clich\u{E9}s readers skim over.",
        "Sentence rhythm": "One bar per sentence, as tall as it is long. Text reads best when long and short sentences mix; many of the same length, or the same first word again and again, reads flat.",
        "Above grade": "Sentences that read above your target grade, by the Flesch-Kincaid formula: long sentences with long words. Split them, or use shorter words.",
        "Long sentences": "Sentences of more than 25 words. Readers lose the thread; most plain-language guides aim for 15 to 20 words on average.",
        "Possible passive voice": "\u{201C}The report was written by the team\u{201D} hides or delays who acts. \u{201C}The team wrote the report\u{201D} is shorter and clearer. Passive is fine when who acts does not matter.",
        "Fiction": "Habits fiction editors mark. Tags other than \u{201C}said\u{201D} draw the eye; filter words (\u{201C}she saw\u{201D}) put distance between reader and scene; named emotions (\u{201C}he felt angry\u{201D}) tell where action could show.",
        "Your crutch words": "Words you have often replaced with a synonym from WordPop. You may lean on them more than you think.",
        "Adverbs": "-ly words often prop up a weak verb: \u{201C}ran quickly\u{201D} \u{2192} sprinted, \u{201C}said quietly\u{201D} \u{2192} whispered. Keep the ones that add meaning.",
        "Hedges and filler": "Words that soften a claim (\u{201C}I think\u{201D}, \u{201C}sort of\u{201D}) or add nothing (\u{201C}just\u{201D}, \u{201C}really\u{201D}). One hedge can be honest; many make the writer sound unsure.",
        "Repeated words": "Content words used three times or more. Repetition can be on purpose; if not, look the word up and pick a synonym.",
    ]
}
