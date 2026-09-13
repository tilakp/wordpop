import SwiftUI
import AppKit

/// A simple wrapping layout for the synonym pills.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct PopupContentView: View {
    @ObservedObject var viewModel: PopupViewModel
    @State private var showOrigin = false

    static let popupWidth: CGFloat = 380
    private static let maxListHeight: CGFloat = 420

    private var hasScrollableContent: Bool {
        !viewModel.entry.items.isEmpty || viewModel.entry.origin != nil
    }

    private var isEmpty: Bool {
        !hasScrollableContent && viewModel.entry.synonyms.isEmpty
            && viewModel.entry.antonyms.isEmpty && viewModel.entry.rhymes.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 14)

            if hasScrollableContent {
                Divider().padding(.horizontal, 22)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if !viewModel.entry.items.isEmpty {
                            itemsList
                        }
                        if let origin = viewModel.entry.origin {
                            originDisclosure(origin)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
                }
                .frame(maxHeight: Self.maxListHeight)
            }

            if !viewModel.entry.synonyms.isEmpty {
                Divider().padding(.horizontal, 22)
                pillSection(title: "Synonyms", words: viewModel.entry.synonyms)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
            }

            if !viewModel.entry.antonyms.isEmpty {
                Divider().padding(.horizontal, 22)
                pillSection(title: "Antonyms", words: viewModel.entry.antonyms)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
            }

            if !viewModel.entry.rhymes.isEmpty {
                Divider().padding(.horizontal, 22)
                pillSection(title: "Rhymes", words: viewModel.entry.rhymes)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
            }

            if isEmpty {
                Text("No definition found for \u{201C}\(viewModel.entry.word)\u{201D}.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)
            }
        }
        .frame(width: Self.popupWidth, alignment: .leading)
        .background(Color.popupPage)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1))
        )
        .onChange(of: viewModel.entry.word) { _, _ in
            showOrigin = false
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if viewModel.canGoBack {
                    Button(action: viewModel.onGoBack) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                Text(viewModel.entry.word)
                    .font(.system(size: 24, weight: .bold))
                    .lineLimit(1)

                if let partOfSpeech = viewModel.entry.partOfSpeech {
                    Text(partOfSpeech)
                        .font(.system(size: 13).italic())
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Button(action: viewModel.onTogglePin) {
                    Image(systemName: viewModel.isPinned ? "pin.fill" : "pin")
                }
                .buttonStyle(.plain)
                .foregroundStyle(viewModel.isPinned ? Color.accentColor : Color.secondary)
                .help(viewModel.isPinned ? "Unpin" : "Pin (keep open)")

                Button(action: viewModel.onClose) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if let pronunciation = viewModel.entry.pronunciation {
                HStack(spacing: 6) {
                    Text(pronunciation)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Button(action: viewModel.onSpeak) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Pronounce (or press Space)")
                }
            }
        }
    }

    private var itemsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(viewModel.entry.items.enumerated()), id: \.offset) { _, item in
                itemRow(item)
            }
        }
    }

    private func itemRow(_ item: DefinitionItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top, spacing: 6) {
                if let number = item.number {
                    Text("\(number).")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else if item.isSubItem {
                    Text("\u{2022}")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Text(item.text)
                    .font(.system(size: 13))
            }
            if let example = item.example {
                Text("\u{201C}\(example)\u{201D}")
                    .font(.system(size: 12).italic())
                    .foregroundStyle(.secondary)
                    .padding(.leading, 19)
            }
        }
        .padding(.leading, item.isSubItem ? 16 : 0)
    }

    private func pillSection(title: String, words: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            FlowLayout(spacing: 6) {
                ForEach(Array(words.prefix(10)), id: \.self) { word in
                    Button(action: { viewModel.onSelectWord(word) }) {
                        Text(word)
                            .font(.system(size: 12))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func originDisclosure(_ origin: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { showOrigin.toggle() }) {
                HStack(spacing: 4) {
                    Text("Origin")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Image(systemName: showOrigin ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if showOrigin {
                Text(origin)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
