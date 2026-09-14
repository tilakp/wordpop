import SwiftUI

final class QuickSearchModel: ObservableObject {
    @Published var query: String = ""
    @Published var selection: Int?

    func reset() {
        query = ""
        selection = nil
    }
}

struct QuickSearchView: View {
    static let width: CGFloat = 380
    private static let maxRows = 8

    private struct Row: Identifiable {
        let word: String
        let date: Date?
        var id: String { word }
    }

    @ObservedObject var model: QuickSearchModel
    @ObservedObject private var history = LookupHistory.shared
    @FocusState private var isFocused: Bool
    let onSubmit: (String) -> Void
    let onLayoutChange: () -> Void

    /// Recent lookups matching the query come first, then dictionary
    /// completions to fill the remaining rows.
    private var rows: [Row] {
        let query = model.query.trimmingCharacters(in: .whitespaces)
        var rows = history.recent(matching: query, limit: Self.maxRows).map { Row(word: $0.word, date: $0.date) }
        let seen = Set(rows.map(\.word))
        for word in WordList.suggestions(for: query, limit: Self.maxRows + seen.count) where !seen.contains(word) {
            guard rows.count < Self.maxRows else { break }
            rows.append(Row(word: word, date: nil))
        }
        return rows
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

            if !rows.isEmpty {
                Divider().padding(.horizontal, 18)
                rowList
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
            }
        }
        .frame(width: Self.width)
        .background(Color.popupPage)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
        .onAppear { isFocused = true }
        .onChange(of: model.query) { _, _ in model.selection = nil }
        .onChange(of: rows.count) { _, _ in onLayoutChange() }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "character.book.closed")
                .foregroundStyle(.secondary)
                .font(.system(size: 17))

            TextField("Look up a word\u{2026}", text: $model.query)
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
                        Text(row.word)
                            .font(.recentWord)
                            .foregroundStyle(.primary)
                        Spacer()
                        if let date = row.date {
                            Text(Self.relativeDate.localizedString(for: date, relativeTo: Date()))
                                .font(.recentMeta)
                                .foregroundStyle(.tertiary)
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
            }
        }
    }

    private func submit() {
        if let selection = model.selection, rows.indices.contains(selection) {
            onSubmit(rows[selection].word)
            return
        }
        let word = model.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        onSubmit(word)
    }

    private func move(by delta: Int) -> KeyPress.Result {
        guard !rows.isEmpty else { return .ignored }
        let current = model.selection ?? -1
        model.selection = min(max(current + delta, 0), rows.count - 1)
        return .handled
    }

    private static let relativeDate: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
