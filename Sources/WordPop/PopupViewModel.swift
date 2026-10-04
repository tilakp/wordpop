import AppKit
import SwiftUI

struct PillRow: Identifiable {
    let id: Int
    let example: String?
    let words: [String]
    /// Index of the first word in the flattened, keyboard-navigable pill list.
    let firstPillIndex: Int
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
    @Published var showUsage: Bool = false
    @Published var focusedPill: Int?
    /// Whether a chosen word can replace the selection the popup was
    /// opened for (not when it came from Quick Search).
    @Published var canReplace = false
    /// Pill words that are rare in everyday English, shown dimmed so the
    /// plainer choices stand out.
    @Published private(set) var rareWords: Set<String> = []

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

    init() {
        entry = .empty
    }

    var canGoBack: Bool { !history.isEmpty }

    var block: PartOfSpeechBlock? {
        entry.blocks.indices.contains(selectedBlock) ? entry.blocks[selectedBlock] : nil
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

        if let block {
            if !block.senses.isEmpty {
                let shown = showAllSenses ? block.senses : Array(block.senses.prefix(Self.collapsedSenseCount))
                let synonymRows = shown.filter { !$0.synonyms.isEmpty }.map { row($0.example, $0.synonyms, limit: Self.pillsPerSense) }
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
        if !entry.confusedWith.isEmpty {
            let caption = entry.confusionSense.map { "\(entry.word): \($0)" }
            sections.append(PillSection(id: "confused", title: "Often confused with", tint: .confusedTint, rows: [row(caption, entry.confusedWith)]))
        }
        var rhymeRows: [PillRow] = []
        if !entry.rhymes.isEmpty { rhymeRows.append(row(nil, entry.rhymes)) }
        if !entry.nearRhymes.isEmpty { rhymeRows.append(row("near rhymes", entry.nearRhymes)) }
        if !rhymeRows.isEmpty {
            sections.append(PillSection(id: "rhymes", title: "Rhymes", tint: .rhymeTint, rows: rhymeRows))
        }
        return sections
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
            focusedPill = nil
        }
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

    func replaceWithFocusedPill() {
        guard canReplace, let focusedPill, pills.indices.contains(focusedPill) else { return }
        onReplace(pills[focusedPill])
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
        showUsage = false
        focusedPill = nil
        entry = newEntry
        let words = Array(Set(sections.flatMap { $0.rows.flatMap(\.words) } + entry.blocks.flatMap { block in
            block.senses.flatMap(\.synonyms) + block.synonyms
        }))
        rareWords = Set(Database.ranks(of: words).filter { $0.value >= Self.rareRank }.keys)
    }
}
