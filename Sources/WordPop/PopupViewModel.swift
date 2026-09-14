import SwiftUI

final class PopupViewModel: ObservableObject {
    @Published var entry: WordEntry
    @Published var isPinned: Bool = false
    @Published var selectedBlock: Int = 0

    private var history: [WordEntry] = []

    var onClose: () -> Void = {}
    var onTogglePin: () -> Void = {}
    var onSpeak: () -> Void = {}
    var onSelectWord: (String) -> Void = { _ in }
    var onGoBack: () -> Void = {}

    init() {
        entry = .empty
    }

    var canGoBack: Bool { !history.isEmpty }

    var block: PartOfSpeechBlock? {
        entry.blocks.indices.contains(selectedBlock) ? entry.blocks[selectedBlock] : nil
    }

    func reset(with newEntry: WordEntry) {
        history.removeAll()
        isPinned = false
        selectedBlock = 0
        entry = newEntry
    }

    func push(_ newEntry: WordEntry) {
        history.append(entry)
        withAnimation(.easeOut(duration: 0.15)) {
            selectedBlock = 0
            entry = newEntry
        }
    }

    func goBack() {
        guard let previous = history.popLast() else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            selectedBlock = 0
            entry = previous
        }
    }
}
