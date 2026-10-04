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
    @ObservedObject private var starred = StarredWords.shared

    static var popupWidth: CGFloat { 380 * Settings.textScale }
    private static let maxListHeight: CGFloat = 340
    private static let scrollFadeHeight: CGFloat = 28

    private var items: [DefinitionItem] { viewModel.block?.items ?? [] }

    private var hasScrollableContent: Bool {
        !items.isEmpty || viewModel.entry.origin != nil || !viewModel.entry.phrases.isEmpty || !viewModel.entry.usageNotes.isEmpty
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

            // When the definitions (capped at maxListHeight) and the pill
            // sections together are taller than the screen allows, the
            // panel is clamped and the definitions used to shrink to a
            // line or two. Instead, everything below the header scrolls
            // as one, with the definitions at full length.
            ViewThatFits(in: .vertical) {
                body(definitionsCapped: true)
                ScrollView { body(definitionsCapped: false).padding(.bottom, Self.scrollFadeHeight) }
                    .overlay(alignment: .bottom) { scrollFade }
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
    }

    private func body(definitionsCapped: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let comparison = viewModel.comparison {
                Divider().padding(.horizontal, 22)
                comparisonView(comparison)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
            }

            if hasScrollableContent {
                Divider().padding(.horizontal, 22)

                if definitionsCapped {
                    // A bare ScrollView is greedy and would always claim the
                    // full maxListHeight, leaving a blank gap under short
                    // entries. Only wrap in one when the content overflows.
                    CappedHeight(maxHeight: Self.maxListHeight) {
                        ViewThatFits(in: .vertical) {
                            definitions
                            ScrollView { definitions.padding(.bottom, Self.scrollFadeHeight) }
                                .overlay(alignment: .bottom) { scrollFade }
                        }
                    }
                } else {
                    definitions
                }
            }

            ForEach(viewModel.sections) { section in
                Divider().padding(.horizontal, 22)
                pillSection(section)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
            }

            if viewModel.collocations == nil, viewModel.entry.found, WritingModel.isAvailable {
                Divider().padding(.horizontal, 22)
                Button(action: viewModel.onLoadCollocations) {
                    Text(viewModel.isLoadingCollocations
                         ? "Finding words that go with \u{201C}\(viewModel.entry.word)\u{201D}\u{2026}"
                         : "What goes with \u{201C}\(viewModel.entry.word)\u{201D}?")
                        .font(.recentMeta)
                        .foregroundStyle(Color.collocationTint)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
            } else if viewModel.collocations?.isEmpty == true {
                Divider().padding(.horizontal, 22)
                Text("No common phrases found.")
                    .font(.recentMeta)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
            }
        }
    }

    private func comparisonView(_ comparison: Comparison) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Compare")
                    .font(.sectionLabel)
                    .tracking(1.2)
                    .foregroundStyle(Color.compareTint)
                    .textCase(.uppercase)
                Spacer()
                Button(action: { viewModel.comparison = nil }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Close the comparison")
            }
            ForEach([(comparison.word, comparison.definition), (comparison.other, comparison.otherDefinition)], id: \.0) { word, definition in
                (Text(word).font(.phrase) + Text("  " + (definition ?? "no definition")).font(.definition).foregroundColor(.secondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let difference = comparison.difference {
                Text(difference)
                    .font(.example)
                    .fixedSize(horizontal: false, vertical: true)
            } else if WritingModel.isAvailable {
                Text("Comparing\u{2026}")
                    .font(.recentMeta)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var scrollFade: some View {
        LinearGradient(colors: [.popupPage.opacity(0), .popupPage], startPoint: .top, endPoint: .bottom)
            .frame(height: Self.scrollFadeHeight)
            .allowsHitTesting(false)
    }

    private var definitions: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !items.isEmpty {
                itemsList
            }
            if !viewModel.entry.usageNotes.isEmpty {
                usageDisclosure
            }
            if !viewModel.entry.phrases.isEmpty {
                phrasesDisclosure
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

                if viewModel.entry.found {
                    let isStarred = starred.contains(viewModel.entry.word)
                    Button(action: viewModel.toggleStar) {
                        Image(systemName: isStarred ? "star.fill" : "star")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isStarred ? Color.yellow : Color.secondary)
                    .help(isStarred ? "Remove from starred words (\u{2318}D)" : "Star this word (\u{2318}D)")
                }

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

            if let pronunciation = viewModel.block?.pronunciation ?? viewModel.entry.pronunciation {
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
                definitionText(item)
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

    private func definitionText(_ item: DefinitionItem) -> Text {
        guard let label = item.label else { return Text(item.text) }
        return Text("\(label) ").font(.example).foregroundColor(.secondary) + Text(item.text)
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
        let isRare = viewModel.rareWords.contains(word.lowercased())
        return Button(action: {
            if viewModel.canReplace, NSEvent.modifierFlags.contains(.option) {
                viewModel.onReplace(word)
            } else if NSEvent.modifierFlags.contains(.shift) {
                viewModel.onCompare(word)
            } else {
                viewModel.onSelectWord(word)
            }
        }) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(word)
                    .font(.pill)
                    .foregroundStyle(isRare ? .secondary : .primary)
                if let label = viewModel.registerLabels[word.lowercased()] {
                    Text(label)
                        .font(.pillLabel)
                        .foregroundStyle(.secondary)
                }
            }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(tint.opacity(focused ? 0.28 : 0.12))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(focused ? tint : tint.opacity(0.25), lineWidth: focused ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .help([isRare ? "Less common word." : nil, viewModel.canReplace ? "\u{2325}-click to replace your selection." : nil,
               "\u{21E7}-click to compare."]
            .compactMap { $0 }.joined(separator: " "))
    }

    private func disclosureLabel(_ title: String, expanded: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.sectionLabel)
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Image(systemName: expanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var phrasesDisclosure: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: { viewModel.showPhrases.toggle() }) {
                disclosureLabel("Phrases (\(viewModel.entry.phrases.count))", expanded: viewModel.showPhrases)
            }
            .buttonStyle(.plain)

            if viewModel.showPhrases {
                ForEach(Array(viewModel.entry.phrases.enumerated()), id: \.offset) { _, phrase in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(phrase.phrase)
                            .font(.phrase)
                        Text(phrase.definition)
                            .font(.definition)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let example = phrase.example {
                            Text("\u{201C}\(example)\u{201D}")
                                .font(.example)
                                .foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var usageDisclosure: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { viewModel.showUsage.toggle() }) {
                disclosureLabel("Usage", expanded: viewModel.showUsage)
            }
            .buttonStyle(.plain)

            if viewModel.showUsage {
                ForEach(viewModel.entry.usageNotes, id: \.self) { note in
                    Text(note)
                        .font(.definition)
                        .foregroundStyle(.secondary)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func originDisclosure(_ origin: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { viewModel.showOrigin.toggle() }) {
                disclosureLabel("Origin", expanded: viewModel.showOrigin)
            }
            .buttonStyle(.plain)

            if viewModel.showOrigin {
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
