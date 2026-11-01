import SwiftUI

final class QuickSearchModel: ObservableObject {
    @Published var query: String = ""
    @Published var selection: Int?
    /// Words the on-device model found for a "?description" query.
    @Published var described: [String] = []
    @Published var isDescribing = false
    /// The meaning the last describe ran for, to tell "no results" apart
    /// from "not asked yet".
    @Published var lastDescribed: String?

    /// Spelling corrections for the query, each with a one-line meaning so
    /// the right word can be picked by sense. Set only when the query is
    /// misspelled and no known word starts with it, so type-ahead still
    /// wins while a word is half typed.
    @Published private(set) var corrections: [(word: String, gloss: String?)] = []

    func updateCorrections() {
        let word = query.trimmingCharacters(in: .whitespaces)
        guard describedMeaning == nil, usagePhrases == nil, pattern == nil, word.count >= 3, !word.contains(" "),
              WordList.suggestions(for: word, limit: 1).isEmpty else {
            corrections = []
            return
        }
        corrections = Spelling.suggestions(for: word).map { ($0, DictionaryLookup.gloss(of: $0)) }
    }

    /// Words matching a pattern query, each with a one-line meaning.
    @Published private(set) var patternMatches: [(word: String, gloss: String?)] = []

    /// A query with * (any letters), ? or _ (one letter) is a pattern,
    /// optionally narrowed by meaning: "con* : agree". A leading ? is the
    /// describe mode instead.
    var pattern: (glob: String, meaning: String?)? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard describedMeaning == nil, usagePhrases == nil, trimmed.contains(where: { "*?_".contains($0) }) else { return nil }
        let parts = trimmed.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        guard let glob = parts.first, !glob.isEmpty, !glob.contains(" "), glob.contains(where: \.isLetter) else { return nil }
        let meaning = parts.count > 1 && !parts[1].isEmpty ? parts[1] : nil
        return (glob.replacingOccurrences(of: "_", with: "?"), meaning)
    }

    func updatePatternMatches() {
        guard let pattern else {
            patternMatches = []
            return
        }
        var matches = Database.words(matching: pattern.glob, limit: pattern.meaning == nil ? 8 : 5000)
        if let meaning = pattern.meaning {
            let related = Self.relatedWords(to: meaning)
            matches = matches.filter(related.contains)
        }
        patternMatches = matches.prefix(8).map { ($0, DictionaryLookup.gloss(of: $0)) }
    }

    /// Synonyms of `word` from the system Thesaurus and the bundled
    /// dataset, lowercased, for narrowing a pattern by meaning.
    private static func relatedWords(to word: String) -> Set<String> {
        let thesaurus = Thesaurus.blocks(for: word).flatMap(\.senses).flatMap(\.synonyms)
        let bundled = Database.groups("synonyms", word: word).values.flatMap { $0 }
        return Set((thesaurus + bundled).map { $0.lowercased() })
    }

    /// A query that starts with a quote mark checks how phrases are used:
    /// "different than | different from.
    var usagePhrases: [String]? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first, "\"\u{201C}".contains(first) else { return nil }
        return trimmed.dropFirst().split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "\"\u{201C}\u{201D}"))) }
            .filter { !$0.isEmpty }
    }

    /// Each phrase of a usage query with how many example sentences use
    /// it and a few of them.
    @Published private(set) var usage: [(phrase: String, count: Int, sentences: [String])] = []

    func updateUsage() {
        guard let phrases = usagePhrases, !phrases.isEmpty else {
            usage = []
            return
        }
        usage = phrases.prefix(4).map { phrase in
            let found = Database.usage(of: phrase, limit: phrases.count == 1 ? 5 : 2)
            return (phrase, found.count, found.sentences)
        }
    }

    /// A query that starts with "?" describes a word instead of naming it.
    var describedMeaning: String? {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("?") else { return nil }
        return String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
    }

    func reset() {
        query = ""
        selection = nil
        described = []
        isDescribing = false
        lastDescribed = nil
        corrections = []
        patternMatches = []
        usage = []
    }

    @MainActor
    func describe() async {
        guard let meaning = describedMeaning, !meaning.isEmpty else { return }
        isDescribing = true
        let words = await WritingModel.words(describedBy: meaning)
        guard describedMeaning == meaning else { return }
        described = words
        selection = words.isEmpty ? nil : 0
        isDescribing = false
        lastDescribed = meaning
    }
}

struct QuickSearchView: View {
    static var width: CGFloat { 380 * Settings.textScale }
    private static let maxRows = 8

    private struct Row: Identifiable {
        let word: String
        let date: Date?
        var isStarred = false
        /// A one-line meaning, shown under spelling corrections.
        var detail: String? = nil
        var id: String { word.lowercased() }
    }

    @ObservedObject var model: QuickSearchModel
    @ObservedObject private var history = LookupHistory.shared
    @ObservedObject private var starred = StarredWords.shared
    @FocusState private var isFocused: Bool
    let onSubmit: (String) -> Void
    let onLayoutChange: () -> Void

    /// Starred words matching the query come first, then recent lookups,
    /// then dictionary completions to fill the remaining rows.
    private var rows: [Row] {
        if model.usagePhrases != nil { return [] }
        if model.describedMeaning != nil {
            return model.described.map { Row(word: $0, date: nil) }
        }
        if model.pattern != nil {
            return model.patternMatches.map { Row(word: $0.word, date: nil, detail: $0.gloss) }
        }
        let query = model.query.trimmingCharacters(in: .whitespaces)
        var rows = starred.matching(query).prefix(Self.maxRows).map { Row(word: $0, date: nil, isStarred: true) }
        var seen = Set(rows.map(\.id))
        for item in history.recent(matching: query, limit: Self.maxRows) where !seen.contains(item.word.lowercased()) {
            guard rows.count < Self.maxRows else { break }
            rows.append(Row(word: item.word, date: item.date))
            seen.insert(item.word.lowercased())
        }
        for word in WordList.suggestions(for: query, limit: Self.maxRows + seen.count) where !seen.contains(word) {
            guard rows.count < Self.maxRows else { break }
            rows.append(Row(word: word, date: nil))
        }
        for correction in model.corrections where !seen.contains(correction.word.lowercased()) {
            guard rows.count < Self.maxRows else { break }
            rows.append(Row(word: correction.word, date: nil, detail: correction.gloss ?? "spelling suggestion"))
        }
        return rows
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

            if model.usagePhrases != nil {
                Divider().padding(.horizontal, 18)
                usageList
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
            } else if !rows.isEmpty {
                Divider().padding(.horizontal, 18)
                rowList
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
            } else if let note = describeNote ?? patternNote {
                Divider().padding(.horizontal, 18)
                Text(note)
                    .font(.recentMeta)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
            }
            if model.query.isEmpty {
                Divider().padding(.horizontal, 18)
                modeHelp
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
        }
        .frame(width: Self.width)
        .background(Color.popupPage)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
        .onAppear { isFocused = true }
        .onChange(of: model.query) { _, _ in
            model.selection = nil
            model.described = []
            model.isDescribing = false
            model.updateCorrections()
            model.updatePatternMatches()
            model.updateUsage()
        }
        // Any change to the rows can change the height, not only their
        // count: spelling corrections carry a second line.
        .onChange(of: rows.map(\.id)) { _, _ in onLayoutChange() }
        .onChange(of: describeNote) { _, _ in onLayoutChange() }
        .onChange(of: patternNote) { _, _ in onLayoutChange() }
        .onChange(of: model.usage.map { "\($0.phrase)\($0.count)" }) { _, _ in onLayoutChange() }
    }

    /// The search modes, shown while the field is empty: a click starts
    /// one, so nobody has to know the prefixes by heart.
    private var modeHelp: some View {
        HStack(spacing: 6) {
            Text("Also:").font(.recentMeta).foregroundStyle(.secondary)
            ForEach([("? Describe", "?"), ("\" Phrase", "\""), ("* Pattern", "*")], id: \.1) { title, prefix in
                Button(action: {
                    model.query = prefix
                    isFocused = true
                }) { ActionChip(title: title) }
                .buttonStyle(.plain)
                .help(Self.modeHelpText[prefix] ?? "")
            }
            Spacer(minLength: 0)
        }
    }

    private static let modeHelpText = [
        "?": "Type ? and a meaning, then Return: \u{201C}?the smell of rain\u{201D} finds petrichor.",
        "\"": "Type a quote mark and a phrase to see how often it is used. Compare two with |.",
        "*": "* stands for any letters and ? for one (con*, b??t). Add \u{201C}: meaning\u{201D} to keep words with that meaning.",
    ]

    /// The mode the query is in, shown as a chip at the start of the field.
    private var modeName: String? {
        if model.describedMeaning != nil { return "Describe" }
        if model.usagePhrases != nil { return "Phrase" }
        if model.pattern != nil { return "Pattern" }
        return nil
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "character.book.closed")
                .foregroundStyle(.secondary)
                .font(.icon(17))
                .accessibilityHidden(true)

            if let modeName {
                ActionChip(title: modeName, isOn: true)
                    .padding(.trailing, 2)
                    .accessibilityLabel("\(modeName) mode")
            }

            TextField("Look up a word", text: $model.query)
                .textFieldStyle(.plain)
                .font(.searchField)
                .focused($isFocused)
                .onSubmit(submit)
                .onKeyPress(.downArrow) { move(by: 1) }
                .onKeyPress(.upArrow) { move(by: -1) }
        }
    }

    private var rowList: some View {
        VStack(spacing: 2) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                Button(action: { onSubmit(row.word) }) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.word)
                                .font(.recentWord)
                                .foregroundStyle(.primary)
                            if let detail = row.detail {
                                Text(detail)
                                    .font(.recentMeta)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        if row.isStarred {
                            Image(systemName: "star.fill")
                                .font(.recentMeta)
                                .foregroundStyle(.yellow)
                        } else if let date = row.date {
                            Text(Self.relativeDate.localizedString(for: date, relativeTo: Date()))
                                .font(.recentMeta)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(model.selection == index ? Color.accentColor.opacity(0.14) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(model.selection == index ? .isSelected : [])
            }
        }
    }

    /// Each phrase of a usage query with its count in the example
    /// sentences and a few of them, the phrase in bold.
    @ViewBuilder
    private var usageList: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.usage.isEmpty {
                Text("Type a phrase to see how often it is used, in about 400,000 example sentences. Compare two with |: \"different than | different from")
                    .font(.recentMeta)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(model.usage.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 3) {
                    (Text(item.phrase).font(.recentWord) + Text("  \(item.count == 0 ? "no" : String(item.count)) sentence\(item.count == 1 ? "" : "s")").font(.recentMeta).foregroundColor(.secondary))
                    ForEach(item.sentences, id: \.self) { sentence in
                        Text(Self.highlighting(item.phrase, in: sentence))
                            .font(.recentMeta)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if !model.usage.isEmpty {
                Text("Example sentences from Tatoeba (CC BY 2.0 FR). A count shows how common a phrase is, not whether it is correct.")
                    .font(.recentMeta)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// `sentence` with the first use of `phrase` (in any case) in bold.
    static func highlighting(_ phrase: String, in sentence: String) -> AttributedString {
        var text = AttributedString(sentence)
        if let range = text.range(of: phrase, options: .caseInsensitive) {
            text[range].inlinePresentationIntent = .stronglyEmphasized
            text[range].foregroundColor = .primary
        }
        return text
    }

    /// What the describe mode has to say when it has no rows to show.
    private var describeNote: String? {
        guard let meaning = model.describedMeaning else { return nil }
        if !WritingModel.isAvailable { return "Describing a word needs Apple Intelligence (macOS 26 or later)." }
        if model.isDescribing { return "Looking for words\u{2026}" }
        if meaning.isEmpty { return "Describe the meaning, then press Return. Suggestions are a starting point, not always right." }
        if model.lastDescribed == meaning { return "No dictionary words found. Try describing it another way." }
        return "Press Return to find words for this meaning."
    }

    private var patternNote: String? {
        guard let pattern = model.pattern else { return nil }
        return pattern.meaning.map { "No words match that pattern and mean \u{201C}\($0)\u{201D}." } ?? "No words match that pattern."
    }

    private func submit() {
        if let selection = model.selection, rows.indices.contains(selection) {
            onSubmit(rows[selection].word)
            return
        }
        if model.pattern != nil {
            if let first = rows.first { onSubmit(first.word) }
            return
        }
        // The usage check updates as you type; there is nothing to open.
        if model.usagePhrases != nil { return }
        if model.describedMeaning != nil {
            Task { await model.describe() }
            return
        }
        let word = model.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        onSubmit(word)
    }

    private func move(by delta: Int) -> KeyPress.Result {
        guard !rows.isEmpty else { return .ignored }
        let current = model.selection ?? -1
        let index = min(max(current + delta, 0), rows.count - 1)
        model.selection = index
        // Focus stays in the field, so VoiceOver hears the row this way.
        let row = rows[index]
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: [row.word, row.detail].compactMap { $0 }.joined(separator: ", "),
                                        .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        return .handled
    }

    private static let relativeDate: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
