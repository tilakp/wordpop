import AppKit
import SwiftUI

struct PillRow: Identifiable {
    let id: Int
    let example: String?
    let words: [String]
    /// Index of the first word in the flattened, keyboard-navigable pill list.
    let firstPillIndex: Int
}

/// A tone a writer can shift a word toward.
enum Tone: String, CaseIterable, Identifiable {
    case formal, casual, vivid, simpler

    var id: String { rawValue }
    var button: String { rawValue.capitalized }
    var title: String {
        switch self {
        case .formal: "More formal"
        case .casual: "More casual"
        case .vivid: "More vivid"
        case .simpler: "Simpler"
        }
    }
    /// How the request is put to the model.
    var instruction: String { self == .simpler ? "simpler" : "more \(rawValue)" }
}

/// Two words side by side: their definitions at once, and the on-device
/// model's one-sentence difference when it answers.
struct Comparison: Equatable {
    let word: String
    let definition: String?
    let other: String
    let otherDefinition: String?
    var difference: String?
}

struct PillSection: Identifiable {
    let id: String
    let title: String
    let tint: Color
    let rows: [PillRow]
}

final class PopupViewModel: ObservableObject {
    @Published var entry: WordEntry
    @Published var isPinned: Bool = false
    @Published var selectedBlock: Int = 0
    @Published var showAllSenses: Bool = false
    @Published var showPhrases: Bool = false
    @Published var showOrigin: Bool = false
    @Published var showAllDefinitions: Bool = false
    @Published var showUsage: Bool = false
    @Published var focusedPill: Int?
    /// Synonyms the on-device model judged to fit the sentence the word
    /// was selected in, best first; empty until it answers.
    @Published var bestFits: [String] = []
    /// The synonyms of the thesaurus sense the sentence uses, once the
    /// model has picked it; tone shifts choose from these.
    var contextSynonyms: [String]?
    /// Whether a chosen word can replace the selection the popup was
    /// opened for (not when it came from Quick Search).
    @Published var canReplace = false
    @Published var comparison: Comparison?
    /// Words that shift the selected word toward a tone, and the tone
    /// being worked out, if any.
    @Published var toneChoices: (tone: Tone, words: [String])?
    @Published var loadingTone: Tone?
    /// Rhymes the on-device model picked for the line the word ends.
    @Published var lineRhymes: [String] = []
    /// A selected phrase the lookup reduced to one word ("spill the
    /// beans" -> spill), with the dictionary's phrase entry for it, or the
    /// model's explanation when the dictionary has none.
    @Published var selectedPhrase: String?
    @Published var phraseMatch: (phrase: Phrase, source: String)?
    @Published var phraseExplanation: String?
    @Published var isExplainingPhrase = false
    var onExplainPhrase: () -> Void = {}
    /// Fresh example sentences from the on-device model, for `exampleSense`.
    @Published var moreExamples: [String]?
    @Published var isLoadingExamples = false
    var onLoadExamples: () -> Void = {}

    /// The sense examples are written for: the one used in the selection's
    /// sentence when known, otherwise the selected block's first.
    var exampleSense: DefinitionItem? {
        displayItems.first { $0.number != nil } ?? displayItems.first
    }
    /// The numbered sense the on-device model judged to match the
    /// sentence the word was selected in, for the block it belongs to.
    @Published var contextSense: (block: Int, number: Int)?
    /// Set when the selection was a passage: the popup shows its
    /// readability notes instead of a dictionary entry.
    @Published var textStats: TextStats?
    /// Suggested rewrites of passage sentences, by original sentence, and
    /// the sentences being rewritten.
    @Published var rewrites: [String: String] = [:]
    @Published var rewriting: Set<String> = []
    var onRewrite: (String, WritingModel.Rewrite) -> Void = { _, _ in }
    var onUseRewrite: (String) -> Void = { _ in }
    /// Phrases with the word from the on-device model ("tough decision");
    /// nil until asked for, as each request takes about a second.
    @Published var collocations: [String]?
    @Published var isLoadingCollocations = false
    /// Pill words that are rare in everyday English, shown dimmed so the
    /// plainer choices stand out.
    @Published private(set) var rareWords: Set<String> = []
    /// Register or region labels for synonyms ("informal", "archaic",
    /// "British"), keyed by lowercased word, shown as a tag on the pill.
    @Published private(set) var registerLabels: [String: String] = [:]
    /// Syllable counts of the entry's rhymes, for grouping them.
    private var rhymeSyllables: [String: Int] = [:]

    private var history: [WordEntry] = []

    private static let collapsedSenseCount = 3
    private static let pillsPerRow = 10
    private static let pillsPerSense = 8
    /// Rank in the frequency-ordered word list from which a word counts as
    /// rare: "meticulous" (16,000) is not, "punctilious" (41,000) is.
    private static let rareRank = 25_000

    var onClose: () -> Void = {}
    var onTogglePin: () -> Void = {}
    var onSpeak: () -> Void = {}
    var onSelectWord: (String) -> Void = { _ in }
    var onGoBack: () -> Void = {}
    var onReplace: (String) -> Void = { _ in }
    var onCompare: (String) -> Void = { _ in }
    var onTone: (Tone) -> Void = { _ in }
    var onLoadCollocations: () -> Void = {}

    init() {
        entry = .empty
    }

    var canGoBack: Bool { !history.isEmpty }

    var block: PartOfSpeechBlock? {
        entry.blocks.indices.contains(selectedBlock) ? entry.blocks[selectedBlock] : nil
    }

    /// The selected block's definitions, with the sense used in the
    /// selection's sentence (and its sub-senses) moved to the top.
    var displayItems: [DefinitionItem] {
        guard let block else { return [] }
        guard let sense = contextSense, sense.block == selectedBlock,
              let start = block.items.firstIndex(where: { $0.number == sense.number }), start > 0 else { return block.items }
        var end = start + 1
        while end < block.items.count, block.items[end].number == nil { end += 1 }
        return Array(block.items[start..<end]) + Array(block.items[..<start]) + Array(block.items[end...])
    }

    func isContextSense(_ item: DefinitionItem) -> Bool {
        guard let sense = contextSense, let number = item.number else { return false }
        return sense.block == selectedBlock && sense.number == number
    }

    var hiddenSenseCount: Int {
        guard let block, !showAllSenses else { return 0 }
        return max(0, block.senses.count - Self.collapsedSenseCount)
    }

    /// The pill sections in display order. Synonyms come per thesaurus
    /// sense when the system Thesaurus has the word, otherwise as one flat
    /// row from the bundled dataset.
    var sections: [PillSection] {
        var sections: [PillSection] = []
        var pillIndex = 0
        var rowID = 0

        func row(_ example: String?, _ words: [String], limit: Int = PopupViewModel.pillsPerRow) -> PillRow {
            let capped = Array(words.prefix(limit))
            defer { pillIndex += capped.count; rowID += 1 }
            return PillRow(id: rowID, example: example, words: capped, firstPillIndex: pillIndex)
        }

        if !entry.suggestions.isEmpty {
            sections.append(PillSection(id: "spelling", title: "Did you mean", tint: .spellingTint, rows: [row(nil, entry.suggestions)]))
        }
        if let toneChoices, !toneChoices.words.isEmpty {
            sections.append(PillSection(id: "tone", title: toneChoices.tone.title, tint: .toneTint, rows: [row(nil, toneChoices.words)]))
        }
        if !bestFits.isEmpty {
            sections.append(PillSection(id: "fits", title: "Fits your sentence", tint: .fitTint, rows: [row(nil, bestFits)]))
        }
        for (kind, title, tint) in [("stronger", "Stronger words", Color.strongerTint), ("inclusive", "Inclusive alternatives", Color.inclusiveTint)] {
            let rows = entry.hints.filter { $0.kind == kind }.map { row($0.caption, $0.words) }
            if !rows.isEmpty { sections.append(PillSection(id: kind, title: title, tint: tint, rows: rows)) }
        }
        if let block {
            if !block.senses.isEmpty {
                let shown = showAllSenses ? block.senses : Array(block.senses.prefix(Self.collapsedSenseCount))
                let synonymRows = shown.filter { !$0.synonyms.isEmpty }.map { sense in
                    // Room for up to two labelled words (informal, archaic),
                    // which come last in the list and a plain cut would drop.
                    let labelled = sense.synonyms.filter { sense.labels[$0.lowercased()] != nil }.prefix(2)
                    let plain = sense.synonyms.filter { sense.labels[$0.lowercased()] == nil }.prefix(Self.pillsPerSense - labelled.count)
                    return row(sense.example, Array(plain + labelled), limit: Self.pillsPerSense)
                }
                if !synonymRows.isEmpty {
                    sections.append(PillSection(id: "synonyms", title: "Synonyms", tint: .synonymTint, rows: synonymRows))
                }
                var antonyms: [String] = []
                for sense in block.senses {
                    for antonym in sense.antonyms where !antonyms.contains(antonym) { antonyms.append(antonym) }
                }
                if !antonyms.isEmpty {
                    sections.append(PillSection(id: "antonyms", title: "Antonyms", tint: .antonymTint, rows: [row(nil, antonyms)]))
                }
            } else {
                if !block.synonyms.isEmpty {
                    sections.append(PillSection(id: "synonyms", title: "Synonyms", tint: .synonymTint, rows: [row(nil, block.synonyms)]))
                }
                if !block.antonyms.isEmpty {
                    sections.append(PillSection(id: "antonyms", title: "Antonyms", tint: .antonymTint, rows: [row(nil, block.antonyms)]))
                }
            }
        }
        if let collocations, !collocations.isEmpty {
            sections.append(PillSection(id: "collocations", title: "Goes with", tint: .collocationTint, rows: [row(nil, collocations)]))
        }
        if !entry.confusedWith.isEmpty {
            let caption = entry.confusionSense.map { "\(entry.word): \($0)" }
            sections.append(PillSection(id: "confused", title: "Often confused with", tint: .confusedTint, rows: [row(caption, entry.confusedWith)]))
        }
        if !lineRhymes.isEmpty {
            sections.append(PillSection(id: "lineRhymes", title: "Rhymes for your line", tint: .rhymeTint, rows: [row(nil, lineRhymes)]))
        }
        var rhymeRows: [PillRow] = []
        // Grouped by syllables for meter: "1 syllable: diet, riot ...".
        let groups = Dictionary(grouping: entry.rhymes) { rhymeSyllables[$0.lowercased()] ?? 0 }
        for count in groups.keys.sorted() {
            let caption = groups.count > 1 ? (count == 0 ? "other" : "\(count) syllable\(count == 1 ? "" : "s")") : nil
            rhymeRows.append(row(caption, groups[count]!))
        }
        if !entry.nearRhymes.isEmpty { rhymeRows.append(row("near rhymes", entry.nearRhymes)) }
        if !rhymeRows.isEmpty {
            sections.append(PillSection(id: "rhymes", title: "Rhymes", tint: .rhymeTint, rows: rhymeRows))
        }
        return sections.filter { section in PopupSection(pillSectionID: section.id).map(Settings.shows) ?? true }
    }

    var pills: [String] {
        sections.flatMap { $0.rows.flatMap(\.words) }
    }

    func reset(with newEntry: WordEntry) {
        history.removeAll()
        isPinned = false
        showEntry(newEntry)
    }

    func push(_ newEntry: WordEntry) {
        history.append(entry)
        withAnimation(.easeOut(duration: 0.15)) {
            showEntry(newEntry)
        }
    }

    func goBack() {
        guard let previous = history.popLast() else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            showEntry(previous)
        }
    }

    func selectBlock(_ index: Int) {
        guard entry.blocks.indices.contains(index) else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            selectedBlock = index
            showAllSenses = false
            showAllDefinitions = false
            moreExamples = nil
            focusedPill = nil
        }
    }

    /// "British English" -> "British", "North American English" ->
    /// "N. American", so the tag stays short next to the word.
    static func shortLabel(_ label: String) -> String {
        label.replacingOccurrences(of: " English", with: "")
            .replacingOccurrences(of: "North American", with: "N. American")
    }

    func moveFocus(by delta: Int) {
        let count = pills.count
        guard count > 0 else { return }
        let current = focusedPill ?? (delta > 0 ? -1 : count)
        focusedPill = (current + delta + count) % count
    }

    func followFocusedPill() {
        guard let focusedPill, pills.indices.contains(focusedPill) else { return }
        onSelectWord(pills[focusedPill])
    }

    /// The synonyms a tone shift chooses from: the selected block's,
    /// everyday ones first.
    var toneCandidates: [String] {
        if let contextSynonyms, !contextSynonyms.isEmpty { return contextSynonyms }
        guard let block else { return [] }
        var words: [String] = []
        for word in block.senses.flatMap(\.synonyms) + block.synonyms where !words.contains(word) { words.append(word) }
        return Array(words.prefix(40))
    }

    func compareWithFocusedPill() {
        guard let focusedPill, pills.indices.contains(focusedPill) else { return }
        onCompare(pills[focusedPill])
    }

    func replaceWithFocusedPill() {
        guard canReplace, let focusedPill, pills.indices.contains(focusedPill) else { return }
        onReplace(pills[focusedPill])
    }

    func toggleStar() {
        guard entry.found else { return }
        StarredWords.shared.toggle(entry.word)
    }

    func copyWord() {
        copy(entry.word)
    }

    func copyDefinition() {
        guard let first = block?.items.first else { return }
        copy("\(entry.word): \(first.text)")
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func showEntry(_ newEntry: WordEntry) {
        selectedBlock = 0
        showAllSenses = false
        showPhrases = false
        showOrigin = false
        showAllDefinitions = false
        showUsage = false
        bestFits = []
        contextSynonyms = nil
        comparison = nil
        toneChoices = nil
        loadingTone = nil
        lineRhymes = []
        selectedPhrase = nil
        phraseMatch = nil
        phraseExplanation = nil
        isExplainingPhrase = false
        moreExamples = nil
        isLoadingExamples = false
        contextSense = nil
        textStats = nil
        rewrites = [:]
        rewriting = []
        collocations = nil
        isLoadingCollocations = false
        focusedPill = nil
        rhymeSyllables = Database.syllables(of: newEntry.rhymes)
        entry = newEntry
        let words = Array(Set(sections.flatMap { $0.rows.flatMap(\.words) } + entry.blocks.flatMap { block in
            block.senses.flatMap(\.synonyms) + block.synonyms
        }))
        rareWords = Set(Database.ranks(of: words).filter { $0.value >= Self.rareRank }.keys)
        registerLabels = entry.blocks.flatMap(\.senses).reduce(into: [:]) { labels, sense in
            labels.merge(sense.labels.mapValues(Self.shortLabel)) { first, _ in first }
        }
    }
}
