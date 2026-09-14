import Foundation

/// Parses a New Oxford American Dictionary entry from its markup. The
/// structure, top to bottom:
///
///     entry(d:title) > hg { hw, syl_txt, ph }
///                    > sg > se1 (one per part of speech)
///                         { posg { pos, infg { sy, inf } }
///                           se2 (numbered sense) { sn, msDict t_first, msDict t_subsense... }
///                           or, for single-sense entries, msDict t_core + msDict t_subsense... }
///                    > subEntryBlock t_phrases | t_phrasalVerbs > subEntry { l, msDict { df, ex } }
///                    > etym
///
/// Each msDict holds an optional register label (`lg`), an optional form
/// (`fg > f`, e.g. "child of"), the definition (`df`) and examples (`ex`).
enum EntryMarkupParser {
    struct Parsed {
        let title: String
        let syllables: String?
        let pronunciation: String?
        let forms: [String]
        let blocks: [(partOfSpeech: String?, items: [DefinitionItem])]
        let origin: String?
        let phrases: [Phrase]
    }

    /// Homographs ("lead" the verb and "lead" the metal) are separate
    /// records; merged, their parts of speech line up one after another,
    /// with every distinct pronunciation kept.
    static func merge(_ entries: [Parsed]) -> Parsed? {
        guard let first = entries.first else { return nil }
        guard entries.count > 1 else { return first }
        var blocks = first.blocks
        for entry in entries.dropFirst() {
            for block in entry.blocks {
                if let index = blocks.firstIndex(where: { $0.partOfSpeech == block.partOfSpeech }) {
                    blocks[index].items += block.items
                } else {
                    blocks.append(block)
                }
            }
        }
        let pronunciations = uniqued(entries.compactMap(\.pronunciation))
        return Parsed(
            title: first.title,
            syllables: first.syllables,
            pronunciation: pronunciations.isEmpty ? nil : pronunciations.joined(separator: ", "),
            forms: first.forms,
            blocks: blocks,
            origin: first.origin,
            phrases: entries.flatMap(\.phrases)
        )
    }

    static func parse(_ markup: String) -> Parsed? {
        guard let root = MarkupDocument.parse(markup), let entry = root.first("entry") else { return nil }
        let header = entry.first("hg")
        let pronunciations = header?.descendants("ph").map(\.text).filter { !$0.isEmpty } ?? []

        var blocks: [(partOfSpeech: String?, items: [DefinitionItem])] = []
        var forms: [String] = []
        for senseGroup in entry.descendants("se1") {
            let posGroup = senseGroup.first("posg")
            let rawPartOfSpeech = posGroup?.first("pos")?.fullText.lowercased()
                .trimmingCharacters(in: CharacterSet.letters.inverted)
            let partOfSpeech = rawPartOfSpeech.flatMap { $0.isEmpty ? nil : $0 }
            if blocks.isEmpty, let posGroup { forms = inflections(in: posGroup) }
            let items = senses(in: senseGroup)
            guard !items.isEmpty else { continue }
            if let index = blocks.firstIndex(where: { $0.partOfSpeech == partOfSpeech }) {
                blocks[index].items += items
            } else {
                blocks.append((partOfSpeech, items))
            }
        }

        return Parsed(
            title: entry.attributes["d:title"] ?? header?.first("hw")?.text ?? "",
            syllables: header?.first("syl_txt")?.text,
            pronunciation: pronunciations.isEmpty ? nil : uniqued(pronunciations).joined(separator: ", "),
            forms: forms,
            blocks: blocks,
            origin: entry.first("etym").map(\.text).flatMap { $0.isEmpty ? nil : $0 },
            phrases: phrases(in: entry)
        )
    }

    /// "(runs)", "(, running | ˈrəniNG |)", "(past; ran)", "(third
    /// singular present goes; present participle going)": every `inf` form,
    /// prefixed by the `sy` label that precedes it.
    private static func inflections(in posGroup: MarkupNode) -> [String] {
        var forms: [String] = []
        for group in posGroup.descendants("infg") {
            var label: String?
            for child in group.children {
                if child.has("sy") {
                    label = child.text
                } else if child.has("inf") {
                    let form = child.text
                    guard !form.isEmpty else { continue }
                    if let label, ["abbreviation", "abbr", "also", "symbol"].contains(label.lowercased()) {
                        continue
                    }
                    forms.append(label.map { "\($0) \(form)" } ?? form)
                    label = nil
                }
            }
        }
        return forms
    }

    private static func senses(in senseGroup: MarkupNode) -> [DefinitionItem] {
        let numbered = senseGroup.descendants("se2")
        let containers = numbered.isEmpty ? [senseGroup] : numbered
        var items: [DefinitionItem] = []
        for container in containers {
            let number = numbered.isEmpty ? nil : container.first("sn").flatMap { Int($0.fullText) }
            var isFirst = true
            for msDict in container.descendants("msDict") {
                guard let item = item(from: msDict, number: isFirst ? number : nil, isSubItem: !isFirst) else { continue }
                items.append(item)
                isFirst = false
            }
        }
        return items
    }

    private static func item(from msDict: MarkupNode, number: Int?, isSubItem: Bool) -> DefinitionItem? {
        let direct = msDict.children
        guard let definition = direct.first(where: { $0.has("df") })?.text, !definition.isEmpty else { return nil }
        let form = direct.first { $0.has("fg") }?.first("f")?.text
        let text = form.map { "(\($0)) \(definition)" } ?? definition
        let label = direct.first { $0.has("lg") }?.text
        return DefinitionItem(
            number: number,
            text: text,
            example: msDict.first("ex")?.text,
            isSubItem: isSubItem,
            label: label.flatMap { $0.isEmpty ? nil : $0 }
        )
    }

    private static func phrases(in entry: MarkupNode) -> [Phrase] {
        var phrases: [Phrase] = []
        for block in entry.descendants("subEntryBlock") where block.has("t_phrases") || block.has("t_phrasalVerbs") {
            for subEntry in block.descendants("subEntry") {
                guard let phrase = subEntry.first("l")?.text, !phrase.isEmpty,
                      let definition = subEntry.first("msDict")?.first("df")?.text, !definition.isEmpty else { continue }
                phrases.append(Phrase(phrase: phrase, definition: definition, example: subEntry.first("ex")?.text))
            }
        }
        return phrases
    }

    private static func uniqued(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
