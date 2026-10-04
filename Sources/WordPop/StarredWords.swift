import AppKit

/// Words the user starred in the popup: a personal word bank, kept in
/// UserDefaults with no expiry, newest first.
final class StarredWords: ObservableObject {
    static let shared = StarredWords()

    @Published private(set) var words: [String]

    private static let key = "WordPop.starredWords"

    private init() {
        words = UserDefaults.standard.stringArray(forKey: Self.key) ?? []
    }

    func contains(_ word: String) -> Bool {
        words.contains { $0.caseInsensitiveCompare(word) == .orderedSame }
    }

    func toggle(_ word: String) {
        if contains(word) {
            words.removeAll { $0.caseInsensitiveCompare(word) == .orderedSame }
        } else {
            words.insert(word, at: 0)
        }
        UserDefaults.standard.set(words, forKey: Self.key)
    }

    func matching(_ prefix: String) -> [String] {
        prefix.isEmpty ? words : words.filter { $0.lowercased().hasPrefix(prefix.lowercased()) }
    }

    /// One word per line, oldest first, for pasting into notes.
    func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(words.reversed().joined(separator: "\n"), forType: .string)
    }
}
