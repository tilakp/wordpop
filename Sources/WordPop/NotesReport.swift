import Foundation

/// The notes on a passage as short Markdown, to paste into a review
/// comment or a message: the counts, then one line for each kind of note
/// the passage has. Hidden sections are left out, as in the popup.
enum NotesReport {
    static func markdown(
        stats: TextStats,
        typos: [(word: String, suggestions: [String])] = [],
        grammar: [GrammarIssue] = [],
        consistency: Consistency = Consistency(),
        style: StyleRules.Report = StyleRules.Report(),
        fiction: FictionNotes = FictionNotes(),
        targetGrade: Int? = nil,
        shows: (PassageSection) -> Bool = { _ in true }
    ) -> String {
        let target = targetGrade.map { " (target \($0))" } ?? ""
        var lines = ["**Notes on the passage:** \(stats.words) words, \(stats.sentences) sentence\(stats.sentences == 1 ? "" : "s"), "
            + "grade \(String(format: "%.1f", stats.grade))\(target)", ""]
        func add(_ title: String, _ items: [String]) {
            if !items.isEmpty { lines.append("- **\(title):** " + items.joined(separator: "; ")) }
        }
        func quoted(_ text: String) -> String {
            "\u{201C}\(text.count > 80 ? String(text.prefix(80)) + "\u{2026}" : text)\u{201D}"
        }
        add("Spelling", typos.map { "\($0.word) \u{2192} \($0.suggestions.first ?? "?")" })
        add("Grammar", grammar.map { "\(quoted(TextStatsView.excerpt(of: $0))) \u{2192} \($0.corrections.first ?? "?")" })
        add("Consistency", consistency.variants.map { $0.joined(separator: " / ") }
            + (consistency.british.isEmpty ? [] : ["British and American spelling mixed (\((consistency.british + consistency.american).joined(separator: ", ")))"])
            + (consistency.mixedQuotes ? ["straight and curly quotes mixed"] : [])
            + (consistency.mixedSpacing ? ["one and two spaces after sentences"] : [])
            + (consistency.acronyms.isEmpty ? [] : ["not spelled out: \(consistency.acronyms.joined(separator: ", "))"]))
        add("Style rules", style.words.map { $0.fix.isEmpty ? "avoid \($0.phrase)" : "\($0.phrase) \u{2192} \($0.fix)" }
            + style.longSentences.map { "over \(style.sentenceLimit ?? 0) words: \(quoted($0))" }
            + style.longParagraphs.map { "paragraph \($0.number) has \($0.sentences) sentences" }
            + (style.ingWords.isEmpty ? [] : ["-ing forms: \(style.ingWords.joined(separator: ", "))"]))
        add("Wordy phrases", stats.wordy.map { flag in
            let fix = flag.fix.isEmpty ? (flag.isCliche ? "" : " \u{2192} remove") : " \u{2192} \(flag.fix)"
            return flag.phrase + fix + (flag.isCliche ? " (clich\u{E9})" : flag.isHiddenVerb ? " (hidden verb)" : "")
        })
        if let targetGrade {
            add("Above grade \(targetGrade)", stats.sentences(above: Double(targetGrade)).map { "grade \(String(format: "%.0f", $0.grade)): \(quoted($0.text))" })
        }
        if shows(.longSentences) { add("Long sentences", stats.longSentences.map { "\($0.words) words: \(quoted($0.text))" }) }
        if shows(.passive) { add("Possible passive voice", stats.passives) }
        if shows(.adverbs) { add("Adverbs", stats.adverbs) }
        if shows(.hedges) { add("Hedges and filler", stats.hedges.map { $0.count > 1 ? "\($0.word) \u{D7}\($0.count)" : $0.word }) }
        if shows(.repeated) { add("Repeated words", stats.repeated.map { "\($0.word) \u{D7}\($0.count)" }) }
        if shows(.rhythm) {
            add("Sentence starts", stats.repeatedStarts.map { "\u{201C}\($0.word)\u{201D} starts \($0.count) of \(stats.sentences) sentences" })
        }
        add("Fiction", (fiction.dialogueShare.map { ["dialogue \(Int(($0 * 100).rounded()))% of words"] } ?? [])
            + fiction.tagAdverbs + fiction.showyTags.map(\.word).map { "tag: \($0)" }
            + (fiction.filterWords.isEmpty ? [] : ["filter words: " + fiction.filterWords.map(\.word).joined(separator: ", ")])
            + fiction.emotionTells.map { "told: \($0)" })
        if lines.count == 2 { lines.append("No notes.") }
        return lines.joined(separator: "\n")
    }
}
