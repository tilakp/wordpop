import SwiftUI

struct QuickSearchView: View {
    static let width: CGFloat = 380

    @State private var query: String = ""
    @FocusState private var isFocused: Bool
    let onSubmit: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "character.book.closed")
                .foregroundStyle(.secondary)
                .font(.system(size: 16))

            TextField("Look up a word\u{2026}", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .focused($isFocused)
                .onSubmit {
                    let word = query.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !word.isEmpty else { return }
                    onSubmit(word)
                    query = ""
                }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(width: Self.width)
        .background(Color.popupPage)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1))
        )
        .onAppear { isFocused = true }
    }
}
