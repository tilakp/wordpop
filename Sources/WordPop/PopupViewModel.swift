import SwiftUI

final class PopupViewModel: ObservableObject {
    @Published var entry: WordEntry
    @Published var isPinned: Bool = false

    private var history: [WordEntry] = []

    /// Matches the `prefix(10)` cap PopupContentView renders synonym pills
    /// with — an online addition beyond this wouldn't actually be visible,
    /// so it's not worth an animated re-layout.
    private static let visibleSynonymCap = 10

    var onClose: () -> Void = {}
    var onTogglePin: () -> Void = {}
    var onSpeak: () -> Void = {}
    var onSelectWord: (String) -> Void = { _ in }
    var onGoBack: () -> Void = {}

    init() {
        entry = .empty
    }

    var canGoBack: Bool { !history.isEmpty }

    func reset(with newEntry: WordEntry) {
        history.removeAll()
        isPinned = false
        entry = newEntry
    }

    func push(_ newEntry: WordEntry) {
        history.append(entry)
        withAnimation(.easeOut(duration: 0.15)) {
            entry = newEntry
        }
    }

    func goBack() {
        guard let previous = history.popLast() else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            entry = previous
        }
    }

    /// Merges in synonyms fetched from the online enhancer, skipping ones
    /// already shown. Ignored if the displayed word has since changed.
    /// Returns whether this actually changes what's visible (the view caps
    /// the pill list at `visibleSynonymCap`), so the caller can skip an
    /// animated re-layout that wouldn't show anything different.
    @discardableResult
    func addOnlineSynonyms(_ extra: [String], forWord word: String) -> Bool {
        guard entry.word.lowercased() == word.lowercased() else { return false }
        let visibleBefore = min(entry.synonyms.count, Self.visibleSynonymCap)

        var seen = Set(entry.synonyms.map { $0.lowercased() })
        var combined = entry.synonyms
        for synonym in extra where seen.insert(synonym.lowercased()).inserted {
            combined.append(synonym)
        }
        guard combined.count != entry.synonyms.count else { return false }

        withAnimation(.easeOut(duration: 0.15)) {
            entry = entry.replacingSynonyms(combined)
        }

        let visibleAfter = min(combined.count, Self.visibleSynonymCap)
        return visibleAfter != visibleBefore
    }
}
