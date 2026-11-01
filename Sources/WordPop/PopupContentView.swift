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

    private var items: [DefinitionItem] { viewModel.displayItems }

    /// Why the word is worth varying: used often in its paragraph, or
    /// one the user has replaced often before.
    private var usageNote: String {
        var notes: [String] = []
        if let uses = viewModel.paragraphUses { notes.append("Used \(uses) times in this paragraph.") }
        if let count = viewModel.replacedCount { notes.append("You have replaced \u{201C}\(viewModel.entry.word)\u{201D} \(count) times before.") }
        return (notes + ["A synonym below can vary it."]).joined(separator: " ")
    }

    private var hasScrollableContent: Bool {
        !items.isEmpty || (viewModel.entry.origin != nil && Settings.shows(.origin))
            || (!viewModel.entry.phrases.isEmpty && Settings.shows(.phrases))
            || (!viewModel.entry.usageNotes.isEmpty && Settings.shows(.usage))
    }

    private var isEmpty: Bool {
        !hasScrollableContent && viewModel.sections.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let stats = viewModel.textStats {
                TextStatsView(stats: stats, viewModel: viewModel)
            } else {
                entryContent
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

    private var entryContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .padding(.bottom, 10)

            // When the definitions (capped at maxListHeight) and the pill
            // sections together are taller than the screen allows, the
            // panel is clamped and the definitions used to shrink to a
            // line or two. Instead, everything below the header scrolls
            // as one, with the definitions at full length.
            ViewThatFits(in: .vertical) {
                body(definitionsCapped: true)
                ScrollView { body(definitionsCapped: false).padding(.bottom, Self.scrollFadeHeight) }
                    .overlay(alignment: .bottom) { scrollFade }
                    // Text scrolling up under the header fades out instead
                    // of being cut at a hard edge.
                    .overlay(alignment: .top) { topFade }
                    // A new entry starts at the top; without a new identity
                    // the scroll view kept the previous word's position and
                    // could open past the definitions.
                    .id(viewModel.entry.word)
            }

            if Settings.showsPillHint, viewModel.entry.found, !viewModel.sections.isEmpty {
                Divider().padding(.horizontal, 22)
                Text(viewModel.canReplace
                     ? "Click: look up \u{B7} \u{2325}-click: put in your text \u{B7} \u{21E7}-click: compare"
                     : "Click: look up \u{B7} \u{21E7}-click: compare")
                    .font(.recentMeta)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 9)
            }

            if isEmpty, viewModel.selectedPhrase == nil {
                Text("No definition found for \u{201C}\(viewModel.entry.word)\u{201D}.")
                    .font(.example)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)
            }
        }
    }

    private func body(definitionsCapped: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let phrase = viewModel.selectedPhrase {
                Divider().padding(.horizontal, 22)
                phraseView(phrase)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
            }
            if let comparison = viewModel.comparison {
                Divider().padding(.horizontal, 22)
                comparisonView(comparison)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
            }
            if viewModel.paragraphUses != nil || viewModel.replacedCount != nil {
                Divider().padding(.horizontal, 22)
                Text(usageNote)
                    .font(.recentMeta)
                    .foregroundStyle(Color.confusedTint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
            }

            if !items.isEmpty {
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
                                .id(viewModel.entry.word)
                        }
                    }
                } else {
                    definitions(collapsible: true)
                }
            }

            let sections = viewModel.sections
            // The main card: the best words to use, then the tone buttons.
            ForEach(sections.filter { $0.group == .main }) { section in
                Divider().padding(.horizontal, 22)
                pillSection(section)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)
            }

            if !viewModel.toneCandidates.isEmpty, Settings.shows(.tone) {
                Divider().padding(.horizontal, 22)
                toneButtons
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
            }

            ForEach([PillGroup.choice, .usage, .sound], id: \.self) { group in
                let groupSections = sections.filter { $0.group == group }
                let extras = group == .usage ? usageExtras : []
                if !groupSections.isEmpty || !extras.isEmpty {
                    Divider().padding(.horizontal, 22)
                    groupHeader(group, contents: groupSections.map(\.title) + extras)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                    if viewModel.isOpen(group) {
                        ForEach(groupSections) { section in
                            pillSection(section)
                                .padding(.horizontal, 22)
                                .padding(.bottom, 16)
                        }
                        if group == .usage { usageGroupExtras }
                    }
                }
            }
        }
    }

    /// The other parts of the Usage group, named for its summary line.
    private var usageExtras: [String] {
        var extras: [String] = []
        if viewModel.describingWords == nil, viewModel.describingPartOfSpeech != nil, WritingModel.isAvailable, Settings.shows(.describing) {
            extras.append("describing")
        }
        if viewModel.collocations == nil, viewModel.entry.found, WritingModel.isAvailable, Settings.shows(.collocations) { extras.append("phrases") }
        if WritingModel.isAvailable, Settings.shows(.examples), viewModel.exampleSense != nil { extras.append("examples") }
        if !viewModel.entry.usageNotes.isEmpty, Settings.shows(.usage) { extras.append("usage") }
        if !viewModel.entry.phrases.isEmpty, Settings.shows(.phrases) { extras.append("idioms") }
        if viewModel.entry.origin != nil, Settings.shows(.origin) { extras.append("origin") }
        return extras
    }

    /// A group's title row: a click opens or closes it, and while closed
    /// it names what is inside.
    private func groupHeader(_ group: PillGroup, contents: [String]) -> some View {
        let open = viewModel.isOpen(group)
        return Button(action: { viewModel.toggle(group) }) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // A group title is a level above the section labels inside
                // it: larger, darker and not in capitals.
                Text(group.title)
                    .font(.phrase)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)
                if !open {
                    Text(contents.map { $0.lowercased() }.joined(separator: ", "))
                        .font(.recentMeta)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 4)
                Image(systemName: open ? "chevron.down" : "chevron.right")
                    .font(.icon(10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(group.title)
        .accessibilityValue(open ? "expanded" : "collapsed")
        .accessibilityHint(open ? "" : contents.joined(separator: ", "))
    }

    /// The links and notes of the Usage group after its pill sections:
    /// describing words, phrases with the word, more examples, usage
    /// notes, idioms and origin.
    @ViewBuilder
    private var usageGroupExtras: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.describingWords == nil, let partOfSpeech = viewModel.describingPartOfSpeech, WritingModel.isAvailable, Settings.shows(.describing) {
                TextLink(viewModel.isLoadingDescribing
                         ? "Finding words\u{2026}"
                         : partOfSpeech == "noun"
                         ? "Words that describe \u{201C}\(viewModel.entry.word)\u{201D}"
                         : "Nouns \u{201C}\(viewModel.entry.word)\u{201D} describes", action: viewModel.onLoadDescribing)
            } else if viewModel.describingWords?.isEmpty == true {
                Text("No describing words found.").font(.recentMeta).foregroundStyle(.secondary)
            }
            if viewModel.collocations == nil, viewModel.entry.found, WritingModel.isAvailable, Settings.shows(.collocations) {
                TextLink(viewModel.isLoadingCollocations
                         ? "Finding phrases\u{2026}"
                         : "Phrases with \u{201C}\(viewModel.entry.word)\u{201D}", action: viewModel.onLoadCollocations)
            } else if viewModel.collocations?.isEmpty == true {
                Text("No common phrases found.").font(.recentMeta).foregroundStyle(.secondary)
            }
            if WritingModel.isAvailable, Settings.shows(.examples), viewModel.exampleSense != nil {
                moreExamplesView
            }
            if !viewModel.entry.usageNotes.isEmpty, Settings.shows(.usage) {
                usageDisclosure
            }
            if !viewModel.entry.phrases.isEmpty, Settings.shows(.phrases) {
                phrasesDisclosure
            }
            if let origin = viewModel.entry.origin, Settings.shows(.origin) {
                originDisclosure(origin)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 16)
    }

    /// The selected idiom: its dictionary phrase entry and where it is
    /// listed, or a link to the model's explanation when the dictionary
    /// has none, marked as such.
    private func phraseView(_ phrase: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title: "Phrase")
            if let match = viewModel.phraseMatch {
                Text(match.phrase.phrase).font(.phrase)
                Text(match.phrase.definition)
                    .font(.definition)
                    .fixedSize(horizontal: false, vertical: true)
                if let example = match.phrase.example {
                    Text("\u{201C}\(example)\u{201D}")
                        .font(.example)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("From the entry for \u{201C}\(match.source)\u{201D}")
                    .font(.recentMeta)
                    .foregroundStyle(.secondary)
            } else if let explanation = viewModel.phraseExplanation {
                Text(phrase).font(.phrase)
                Text(explanation)
                    .font(.definition)
                    .fixedSize(horizontal: false, vertical: true)
                Text("From Apple Intelligence, not the dictionary; it may be wrong.")
                    .font(.recentMeta)
                    .foregroundStyle(.secondary)
            } else if WritingModel.isAvailable {
                Text("\u{201C}\(phrase)\u{201D} is not in the dictionary as a phrase.")
                    .font(.recentMeta)
                    .foregroundStyle(.secondary)
                TextLink(viewModel.isExplainingPhrase ? "Explaining\u{2026}" : "Explain it with Apple Intelligence", action: viewModel.onExplainPhrase)
            } else {
                Text("\u{201C}\(phrase)\u{201D} is not in the dictionary as a phrase.")
                    .font(.recentMeta)
                    .foregroundStyle(.secondary)
            }
            if viewModel.canReplace, !TextTool.useful(for: phrase).isEmpty {
                TextToolControls(viewModel: viewModel).padding(.top, 4)
            }
        }
    }

    private func comparisonView(_ comparison: Comparison) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(title: "Compare")
                Spacer()
                Button(action: { viewModel.comparison = nil }) {
                    Image(systemName: "xmark")
                        .font(.icon(10, weight: .semibold))
                        .frame(minWidth: 24, minHeight: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Close the comparison")
                .accessibilityLabel("Close the comparison")
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
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Formal, Casual, Vivid and Simpler: each lists up to three synonyms
    /// in that tone as a pill row. Simpler needs no model; the others
    /// appear only with Apple Intelligence.
    private var toneButtons: some View {
        HStack(spacing: 6) {
            SectionLabel(title: "Tone").padding(.trailing, 4)
            ForEach(Tone.allCases.filter { $0 == .simpler || WritingModel.isAvailable }) { tone in
                Button(action: { viewModel.onTone(tone) }) {
                    ActionChip(title: viewModel.loadingTone == tone ? "\(tone.button)\u{2026}" : tone.button, isOn: viewModel.toneChoices?.tone == tone)
                }
                .buttonStyle(.plain)
            }
            if let choices = viewModel.toneChoices, choices.words.isEmpty {
                Text("none found")
                    .font(.recentMeta)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var topFade: some View {
        LinearGradient(colors: [.popupPage, .popupPage.opacity(0)], startPoint: .top, endPoint: .bottom)
            .frame(height: 12)
            .allowsHitTesting(false)
    }

    private var scrollFade: some View {
        LinearGradient(colors: [.popupPage.opacity(0), .popupPage], startPoint: .top, endPoint: .bottom)
            .frame(height: Self.scrollFadeHeight)
            .allowsHitTesting(false)
    }

    private var definitions: some View { definitions(collapsible: false) }

    /// In the scrolling layout a long entry shows its first senses and a
    /// link to the rest, so the synonyms and other pills stay a short
    /// scroll away instead of after every sense of "run".
    private func definitions(collapsible: Bool) -> some View {
        let shown = collapsible && !viewModel.showAllDefinitions ? Self.firstSenses(of: items) : items
        return VStack(alignment: .leading, spacing: 14) {
            if !shown.isEmpty {
                itemsList(shown)
            }
            if shown.count < items.count {
                let senses = items.filter { $0.number != nil }.count
                TextLink(senses > 3 ? "Show all \(senses) senses" : "Show all uses") { viewModel.showAllDefinitions = true }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            if viewModel.canGoBack {
                Button(action: viewModel.onGoBack) {
                    Label(viewModel.previousWord ?? "Back", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                        .font(.link)
                        .lineLimit(1)
                        .frame(minHeight: 20, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Back (\u{2318}[)")
                .accessibilityLabel("Back to \(viewModel.previousWord ?? "the previous word")")
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
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
                    .accessibilityLabel(isStarred ? "Remove star" : "Star")
                }

                Button(action: viewModel.onTogglePin) {
                    Image(systemName: viewModel.isPinned ? "pin.fill" : "pin")
                }
                .buttonStyle(.plain)
                .foregroundStyle(viewModel.isPinned ? Color.accentColor : Color.secondary)
                .help(viewModel.isPinned ? "Unpin" : "Pin (keep open)")
                .accessibilityLabel("Pin")
                .accessibilityValue(viewModel.isPinned ? "on" : "off")

                Button(action: viewModel.onClose) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Close (Esc)")
                .accessibilityLabel("Close")
            }

            if let pronunciation = viewModel.block?.pronunciation ?? viewModel.entry.pronunciation {
                HStack(spacing: 6) {
                    Text(pronunciation)
                        .font(.pronunciation)
                        .foregroundStyle(.secondary)
                    Button(action: viewModel.onSpeak) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.icon(11))
                            .frame(minWidth: 24, minHeight: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("Pronounce (or press Space)")
                    .accessibilityLabel("Pronounce")
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
                    .foregroundStyle(.secondary)
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

    /// The first three numbered senses, each with at most two of its
    /// sub-senses: enough to see what the word means without scrolling
    /// past ten uses of "run" in racing and cricket.
    private static func firstSenses(of items: [DefinitionItem]) -> [DefinitionItem] {
        var numbered = 0, subItems = 0
        return items.filter { item in
            if item.isSubItem {
                subItems += 1
                return numbered <= 3 && subItems <= 2
            }
            if item.number != nil { numbered += 1 }
            subItems = 0
            return numbered <= 3
        }
    }

    private func itemsList(_ items: [DefinitionItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                itemRow(item)
            }
        }
    }

    private func itemRow(_ item: DefinitionItem) -> some View {
        let inSentence = viewModel.isContextSense(item)
        return VStack(alignment: .leading, spacing: 3) {
            if inSentence {
                Label("In your sentence", systemImage: "checkmark")
                    .font(.sectionLabel)
                    .tracking(0.8)
                    .foregroundStyle(Color.fitTint)
                    .textCase(.uppercase)
            }
            HStack(alignment: .top, spacing: 6) {
                if let number = item.number {
                    Text("\(number)")
                        .font(.senseNumber)
                        .foregroundStyle(Color.accentColor)
                        .frame(minWidth: 14 * Settings.textScale, alignment: .trailing)
                } else if item.isSubItem {
                    Text("\u{2022}")
                        .font(.definition)
                        .foregroundStyle(.tertiary)
                        .frame(minWidth: 14 * Settings.textScale, alignment: .trailing)
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
            SectionLabel(title: section.title)
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
            if section.id == "spelling" {
                HStack(spacing: 16) {
                    if viewModel.canReplace, let best = section.rows.first?.words.first {
                        Button(action: { viewModel.onReplace(best) }) { ActionChip(title: "Replace with \u{201C}\(best)\u{201D}") }
                            .buttonStyle(.plain)
                            .help((section.rows.first?.words.count ?? 0) > 1 ? "\u{2325}-click another word to use it instead" : "")
                    }
                    notATypoButton {
                        Spelling.learn(viewModel.entry.word)
                        viewModel.onClose()
                    }
                }
                .padding(.top, 2)
            }
            if section.id == "synonyms", viewModel.hiddenSenseCount > 0 {
                TextLink("\(viewModel.hiddenSenseCount) more sense\(viewModel.hiddenSenseCount == 1 ? "" : "s")") {
                    if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                        viewModel.showAllSenses = true
                    } else {
                        withAnimation(.easeOut(duration: 0.15)) { viewModel.showAllSenses = true }
                    }
                }
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
            // A rare word is tagged, not dimmed, so it does not look disabled.
            WordChip(text: word, tint: tint, label: viewModel.registerLabels[word.lowercased()] ?? (isRare ? "rare" : nil), selected: focused)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Looks up \(word)")
        // VoiceOver cannot send the option and shift clicks.
        .accessibilityAction(named: "Compare") { viewModel.onCompare(word) }
        .modifier(ReplaceAction(enabled: viewModel.canReplace) { viewModel.onReplace(word) })
        .help([isRare ? "Less common word." : nil, viewModel.canReplace ? "\u{2325}-click to replace your selection." : nil,
               "\u{21E7}-click to compare."]
            .compactMap { $0 }.joined(separator: " "))
    }

    private var phrasesDisclosure: some View {
        VStack(alignment: .leading, spacing: 10) {
            DisclosureRow(title: "Idioms (\(viewModel.entry.phrases.count))", expanded: viewModel.showPhrases) { viewModel.showPhrases.toggle() }

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
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    /// "More examples" asks the on-device model for three sentences in the
    /// sense shown first; they replace the link when they arrive.
    @ViewBuilder private var moreExamplesView: some View {
        if let examples = viewModel.moreExamples {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(title: "More examples")
                if examples.isEmpty {
                    Text("No examples came back.").font(.recentMeta).foregroundStyle(.secondary)
                }
                ForEach(examples, id: \.self) { sentence in
                    Text("\u{201C}\(sentence)\u{201D}")
                        .font(.example)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            TextLink(viewModel.isLoadingExamples ? "Writing examples\u{2026}" : "More examples", action: viewModel.onLoadExamples)
        }
    }

    private var usageDisclosure: some View {
        VStack(alignment: .leading, spacing: 6) {
            DisclosureRow(title: "Usage notes", expanded: viewModel.showUsage) { viewModel.showUsage.toggle() }

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
            DisclosureRow(title: "Origin", expanded: viewModel.showOrigin) { viewModel.showOrigin.toggle() }

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

/// A VoiceOver action that puts a word in place of the selection, when
/// the popup can replace it.
private struct ReplaceAction: ViewModifier {
    let enabled: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.accessibilityAction(named: "Replace selection", action)
        } else {
            content
        }
    }
}
