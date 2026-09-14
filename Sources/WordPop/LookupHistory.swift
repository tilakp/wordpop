import Foundation

struct HistoryItem: Codable, Equatable, Identifiable {
    let word: String
    let date: Date

    var id: String { word }
}

/// Recent lookups, persisted in UserDefaults and kept for 30 days. One
/// entry per word (case-insensitive); looking a word up again moves it to
/// the front.
final class LookupHistory: ObservableObject {
    static let shared = LookupHistory()

    @Published private(set) var items: [HistoryItem]

    private static let key = "WordPop.lookupHistory"
    private static let retention: TimeInterval = 30 * 24 * 60 * 60
    private static let maxItems = 500

    private init() {
        items = Self.load()
        prune()
    }

    func record(_ word: String) {
        let normalized = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return }
        items.removeAll { $0.word == normalized }
        items.insert(HistoryItem(word: normalized, date: Date()), at: 0)
        prune()
        save()
    }

    func clear() {
        items = []
        save()
    }

    func recent(matching prefix: String, limit: Int) -> [HistoryItem] {
        let needle = prefix.lowercased()
        return Array(items.lazy.filter { needle.isEmpty || $0.word.hasPrefix(needle) }.prefix(limit))
    }

    private func prune() {
        let cutoff = Date().addingTimeInterval(-Self.retention)
        items = Array(items.filter { $0.date > cutoff }.prefix(Self.maxItems))
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    private static func load() -> [HistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) else {
            return []
        }
        return decoded
    }
}
