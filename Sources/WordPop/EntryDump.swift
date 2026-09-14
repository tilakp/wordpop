import Foundation

/// Plain-text rendering of a parsed entry for `WordPop --lookup <word>`.
enum EntryDump {
    static func text(for entry: WordEntry) -> String {
        var lines: [String] = []
        lines.append("word: \(entry.word)")
        if let syllables = entry.syllables { lines.append("syllables: \(syllables)") }
        if let pronunciation = entry.pronunciation { lines.append("pronunciation: \(pronunciation)") }
        if !entry.forms.isEmpty { lines.append("forms: \(entry.forms.joined(separator: " · "))") }
        for block in entry.blocks {
            lines.append("")
            lines.append("[\(block.partOfSpeech ?? "-")]")
            for item in block.items {
                let marker = item.number.map { "\($0)." } ?? (item.isSubItem ? "  •" : "-")
                lines.append("\(marker) \(item.text)")
                if let example = item.example { lines.append("    \u{201C}\(example)\u{201D}") }
            }
            for (index, sense) in block.senses.enumerated() {
                lines.append("sense \(index + 1): \(sense.example ?? "-")")
                lines.append("    synonyms: \(sense.synonyms.joined(separator: ", "))")
                if !sense.antonyms.isEmpty { lines.append("    antonyms: \(sense.antonyms.joined(separator: ", "))") }
            }
            if block.senses.isEmpty {
                if !block.synonyms.isEmpty { lines.append("synonyms: \(block.synonyms.joined(separator: ", "))") }
                if !block.antonyms.isEmpty { lines.append("antonyms: \(block.antonyms.joined(separator: ", "))") }
            }
        }
        if !entry.rhymes.isEmpty { lines.append("\nrhymes: \(entry.rhymes.joined(separator: ", "))") }
        if let origin = entry.origin { lines.append("\norigin: \(origin)") }
        if let source = entry.source { lines.append("\nsource: \(source)") }
        if !entry.found { lines.append("(not found)") }
        return lines.joined(separator: "\n")
    }
}
