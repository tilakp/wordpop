import Foundation

/// Best-effort online enhancement for synonyms, used to fill in words the
/// offline WordNet-based dataset has thin or no coverage for (e.g. words
/// that are the sole member of their WordNet synset, like "serendipity").
/// Never blocks the popup: the offline result is always shown first, and
/// this only adds to it if a response comes back in time.
enum SynonymEnhancer {
    private struct DatamuseWord: Decodable {
        let word: String
    }

    static func fetchOnline(for word: String) async -> [String] {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.datamuse.com/words?ml=\(encoded)&max=15") else {
            return []
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let items = try? JSONDecoder().decode([DatamuseWord].self, from: data) else {
            return []
        }

        let lowerWord = trimmed.lowercased()
        var seen = Set<String>()
        var result: [String] = []
        for item in items {
            let candidate = item.word.lowercased()
            guard candidate != lowerWord, candidate.split(separator: " ").count <= 3 else { continue }
            guard seen.insert(candidate).inserted else { continue }
            result.append(candidate)
        }
        return result
    }
}
