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
    private static let maxRecent = 8

    @ObservedObject var model: QuickSearchModel
    @ObservedObject private var history = LookupHistory.shared
    @FocusState private var isFocused: Bool
    let onSubmit: (String) -> Void
    let onLayoutChange: () -> Void

    private var recent: [HistoryItem] {
        history.recent(matching: model.query.trimmingCharacters(in: .whitespaces), limit: Self.maxRecent)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

            if !recent.isEmpty {
                Divider().padding(.horizontal, 18)
                recentList
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
        .onChange(of: recent.count) { _, _ in onLayoutChange() }
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

    private var recentList: some View {
        VStack(spacing: 2) {
            ForEach(Array(recent.enumerated()), id: \.element.id) { index, item in
                Button(action: { onSubmit(item.word) }) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.word)
                            .font(.recentWord)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(Self.relativeDate.localizedString(for: item.date, relativeTo: Date()))
                            .font(.recentMeta)
                            .foregroundStyle(.tertiary)
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
        if let selection = model.selection, recent.indices.contains(selection) {
            onSubmit(recent[selection].word)
            return
        }
        let word = model.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { return }
        onSubmit(word)
    }

    private func move(by delta: Int) -> KeyPress.Result {
        guard !recent.isEmpty else { return .ignored }
        let current = model.selection ?? -1
        model.selection = min(max(current + delta, 0), recent.count - 1)
        return .handled
    }

    private static let relativeDate: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
