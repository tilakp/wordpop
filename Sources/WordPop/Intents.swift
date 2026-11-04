import AppIntents
import AppKit

// Actions for Shortcuts, Spotlight and Siri. Shortcuts finds them through
// Metadata.appintents, which build_app.sh makes with Xcode's
// appintentsmetadataprocessor (swift build alone does not).

struct LookUpWordIntent: AppIntent {
    static let title: LocalizedStringResource = "Look Up Word"
    static let description = IntentDescription("Shows a word in the WordPop popup and gives its first definition.")

    @Parameter(title: "Word")
    var word: String

    @Parameter(title: "Show the Popup", default: true)
    var showPopup: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Look up \(\.$word)") { \.$showPopup }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let word = word.trimmingCharacters(in: .whitespacesAndNewlines)
        if showPopup { (NSApp.delegate as? AppDelegate)?.showLookup(word) }
        guard let definition = DictionaryLookup.firstDefinition(of: word) else { return .result(value: "") }
        return .result(value: definition.partOfSpeech.map { "\($0): \(definition.text)" } ?? definition.text)
    }
}

struct FindSynonymsIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Synonyms"
    static let description = IntentDescription("Gives the synonyms of a word, most common sense first.")

    @Parameter(title: "Word")
    var word: String

    static var parameterSummary: some ParameterSummary {
        Summary("Find synonyms of \(\.$word)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let entry = DictionaryLookup.lookup(word.trimmingCharacters(in: .whitespacesAndNewlines))
        var synonyms: [String] = []
        for block in entry.blocks {
            for synonym in block.senses.flatMap(\.synonyms) + block.synonyms where !synonyms.contains(synonym) {
                synonyms.append(synonym)
            }
        }
        return .result(value: synonyms)
    }
}

struct CheckTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Text"
    static let description = IntentDescription("Gives WordPop's notes on a passage as Markdown: spelling, grammar, wordy phrases, long sentences and more.")

    @Parameter(title: "Text", inputOptions: String.IntentInputOptions(multiline: true))
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Check \(\.$text)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // The same checks as the passage popup, without its choices.
        var stats = TextStats.analyze(text, syllables: { Database.syllables(of: $0) }, flags: Settings.shows(.wordy) ? Database.phraseFlags : [])
        var style = StyleRules.Report()
        let rules = StyleRules.current
        if !rules.isEmpty {
            style = rules.check(text, sentences: stats.sentenceTexts)
            let covered = Set(style.words.map { $0.phrase.lowercased() })
            stats.wordy.removeAll { covered.contains($0.phrase.lowercased()) }
        }
        let report = NotesReport.markdown(
            stats: stats, typos: Spelling.typos(in: text), grammar: Spelling.grammarIssues(in: text),
            consistency: Settings.shows(.consistency) ? Consistency.check(text) : Consistency(),
            style: style, fiction: Settings.showsFiction ? FictionNotes.check(text) : FictionNotes(),
            targetGrade: Settings.targetGrade, shows: Settings.shows
        )
        return .result(value: report)
    }
}

struct WordPopShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LookUpWordIntent(), phrases: ["Look up a word in \(.applicationName)"],
                    shortTitle: "Look Up Word", systemImageName: "character.book.closed")
        AppShortcut(intent: FindSynonymsIntent(), phrases: ["Find synonyms in \(.applicationName)"],
                    shortTitle: "Find Synonyms", systemImageName: "text.word.spacing")
        AppShortcut(intent: CheckTextIntent(), phrases: ["Check text with \(.applicationName)"],
                    shortTitle: "Check Text", systemImageName: "checkmark.bubble")
    }
}
