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

                // A bare ScrollView is greedy and would always claim the
                // full maxListHeight, leaving a blank gap under short
                // entries. Only wrap in one when the content overflows.
                CappedHeight(maxHeight: Self.maxListHeight) {
                    ViewThatFits(in: .vertical) {
                        definitions
                        ScrollView { definitions }
                    }
                }
            }

            if !viewModel.entry.synonyms.isEmpty {
                Divider().padding(.horizontal, 22)
                pillSection(title: "Synonyms", words: viewModel.entry.synonyms, tint: .synonymTint)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
            }

            if !viewModel.entry.antonyms.isEmpty {
                Divider().padding(.horizontal, 22)
                pillSection(title: "Antonyms", words: viewModel.entry.antonyms, tint: .antonymTint)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
            }

            if !viewModel.entry.rhymes.isEmpty {
                Divider().padding(.horizontal, 22)
                pillSection(title: "Rhymes", words: viewModel.entry.rhymes, tint: .rhymeTint)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
            }

            if isEmpty {
                Text("No definition found for \u{201C}\(viewModel.entry.word)\u{201D}.")
                    .font(.example)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)
            }
        }
        .frame(width: Self.popupWidth, alignment: .leading)
        .background(Color.popupPage)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
        .onChange(of: viewModel.entry.word) { _, _ in
            showOrigin = false
        }
    }

    private var definitions: some View {
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
                    .font(.headword)
                    .tracking(-0.3)
                    .lineLimit(1)

                if let partOfSpeech = viewModel.entry.partOfSpeech {
                    Text(partOfSpeech)
                        .font(.partOfSpeech)
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
                        .font(.pronunciation)
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
                    Text("\(number)")
                        .font(.senseNumber)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 14, alignment: .trailing)
                } else if item.isSubItem {
                    Text("\u{2022}")
                        .font(.definition)
                        .foregroundStyle(.tertiary)
                        .frame(width: 14, alignment: .trailing)
                }
                Text(item.text)
                    .font(.definition)
                    .lineSpacing(2)
            }
            if let example = item.example {
                Text("\u{201C}\(example)\u{201D}")
                    .font(.example)
                    .foregroundStyle(.secondary)
                    .lineSpacing(1)
                    .padding(.leading, 20)
            }
        }
        .padding(.leading, item.isSubItem ? 16 : 0)
    }

    private func pillSection(title: String, words: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.sectionLabel)
                .tracking(1.2)
                .foregroundStyle(tint)
                .textCase(.uppercase)
            FlowLayout(spacing: 6) {
                ForEach(Array(words.prefix(10)), id: \.self) { word in
                    Button(action: { viewModel.onSelectWord(word) }) {
                        Text(word)
                            .font(.pill)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(tint.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(tint.opacity(0.25)))
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
                        .font(.sectionLabel)
                        .tracking(1.2)
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
                    .font(.origin)
                    .foregroundStyle(.secondary)
                    .lineSpacing(1)
            }
        }
    }
}

/// Proposes at most `maxHeight` to its child but reports the child's actual
/// size. `.frame(maxHeight:)` cannot do this: it expands to fill the
/// proposal, which is what left the blank gap.
private struct CappedHeight: Layout {
    var maxHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let capped = ProposedViewSize(width: proposal.width, height: min(proposal.height ?? maxHeight, maxHeight))
        return subviews[0].sizeThatFits(capped)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let capped = ProposedViewSize(width: bounds.width, height: min(bounds.height, maxHeight))
        subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: capped)
    }
}
