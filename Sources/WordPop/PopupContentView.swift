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
    private static let maxListHeight: CGFloat = 340
    private static let scrollFadeHeight: CGFloat = 28

    private var items: [DefinitionItem] { viewModel.block?.items ?? [] }

    private var hasScrollableContent: Bool {
        !items.isEmpty || viewModel.entry.origin != nil
    }

    private var isEmpty: Bool {
        !hasScrollableContent && viewModel.sections.isEmpty
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
                        ScrollView { definitions.padding(.bottom, Self.scrollFadeHeight) }
                            .overlay(alignment: .bottom) {
                                LinearGradient(colors: [.popupPage.opacity(0), .popupPage], startPoint: .top, endPoint: .bottom)
                                    .frame(height: Self.scrollFadeHeight)
                                    .allowsHitTesting(false)
                            }
                    }
                }
            }

            ForEach(viewModel.sections) { section in
                Divider().padding(.horizontal, 22)
                pillSection(section)
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
            if !items.isEmpty {
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

                Text(viewModel.entry.syllables ?? viewModel.entry.word)
                    .font(.headword)
                    .tracking(-0.3)
                    .lineLimit(1)

                if viewModel.entry.blocks.count == 1, let partOfSpeech = viewModel.block?.partOfSpeech {
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

            if !viewModel.entry.forms.isEmpty {
                Text(viewModel.entry.forms.joined(separator: "  \u{B7}  "))
                    .font(.forms)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let source = viewModel.entry.source {
                Text(source)
                    .font(.recentMeta)
                    .foregroundStyle(.tertiary)
            }

            if viewModel.entry.blocks.count > 1 {
                partOfSpeechSwitcher
                    .padding(.top, 6)
            }
        }
    }

    private var partOfSpeechSwitcher: some View {
        HStack(spacing: 14) {
            ForEach(Array(viewModel.entry.blocks.enumerated()), id: \.offset) { index, block in
                let isSelected = index == viewModel.selectedBlock
                Button(action: { viewModel.selectBlock(index) }) {
                    Text(block.partOfSpeech ?? "other")
                        .font(.partOfSpeech)
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        .padding(.bottom, 2)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(isSelected ? Color.accentColor : Color.clear)
                                .frame(height: 1.5)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var itemsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
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
                // fixedSize so a long single-paragraph entry reports its
                // real height; otherwise Text truncates to the proposal and
                // ViewThatFits never falls back to the ScrollView.
                Text(item.text)
                    .font(.definition)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let example = item.example {
                Text("\u{201C}\(example)\u{201D}")
                    .font(.example)
                    .foregroundStyle(.secondary)
                    .lineSpacing(1)
                    .padding(.leading, 20)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.leading, item.isSubItem ? 16 : 0)
    }

    private func pillSection(_ section: PillSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.sectionLabel)
                .tracking(1.2)
                .foregroundStyle(section.tint)
                .textCase(.uppercase)
            ForEach(section.rows) { row in
                VStack(alignment: .leading, spacing: 5) {
                    if let example = row.example {
                        Text(example)
                            .font(.example)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    FlowLayout(spacing: 6) {
                        ForEach(Array(row.words.enumerated()), id: \.offset) { offset, word in
                            pill(word, tint: section.tint, focused: viewModel.focusedPill == row.firstPillIndex + offset)
                        }
                    }
                }
                .padding(.top, row.example != nil && row.id != section.rows.first?.id ? 4 : 0)
            }
            if section.id == "synonyms", viewModel.hiddenSenseCount > 0 {
                Button(action: { withAnimation(.easeOut(duration: 0.15)) { viewModel.showAllSenses = true } }) {
                    Text("\(viewModel.hiddenSenseCount) more sense\(viewModel.hiddenSenseCount == 1 ? "" : "s")")
                        .font(.recentMeta)
                        .foregroundStyle(section.tint)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }

    private func pill(_ word: String, tint: Color, focused: Bool) -> some View {
        Button(action: { viewModel.onSelectWord(word) }) {
            Text(word)
                .font(.pill)
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(tint.opacity(focused ? 0.28 : 0.12))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(focused ? tint : tint.opacity(0.25), lineWidth: focused ? 1.5 : 1))
        }
        .buttonStyle(.plain)
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
                    .fixedSize(horizontal: false, vertical: true)
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
