import SwiftUI

/// The popup's view of a selected passage: counts and reading grade at the
/// top, then the sentences and words worth a second look.
struct TextStatsView: View {
    let stats: TextStats
    @ObservedObject var viewModel: PopupViewModel
    @State private var copiedNotes = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Selected text")
                    .font(.headword)
                    .tracking(-0.3)
                Spacer()
                Button(action: viewModel.onClose) { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 6)

            (Text(summary) + gradeTarget)
                .font(.forms)
                .foregroundStyle(.secondary)
                // Wraps instead of being cut short when a tool opens below.
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 22)
                .padding(.bottom, 14)

            if Settings.shows(.tools) {
                section("Tools") { toolControls }
            }

            // Mistakes: what the Fix button corrects, with the button first.
            if hasMistakes {
                groupHeader("Mistakes", count: nil, open: true)
                if viewModel.canReplace, viewModel.hasFixes {
                    applyFixesButton
                        .padding(.horizontal, 22)
                        .padding(.bottom, 4)
                }
                if !viewModel.typos.isEmpty {
                    section("Spelling", divider: false) { typoControls }
                }
                if !viewModel.grammar.isEmpty {
                    section("Grammar", divider: false) { grammarControls }
                }
                if !viewModel.consistency.isEmpty {
                    section("Consistency", divider: false) { consistencyControls }
                }
                if !viewModel.style.words.isEmpty {
                    section("Style rules", divider: false) { styleWordControls }
                }
                if !stats.wordy.isEmpty {
                    section("Wordy phrases and clich\u{E9}s", divider: false) { phraseControls }
                }
            }

            // Clarity: sentences that are hard to read.
            if hasClarityNotes {
                groupHeader("Clarity", count: nil, open: true)
                if !hardSentenceNotes.isEmpty {
                    section("Hard sentences", divider: false) {
                        ForEach(Array(hardSentenceNotes.prefix(4).enumerated()), id: \.offset) { _, sentence in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(sentence.reasons.joined(separator: " \u{B7} "))
                                    .font(.recentMeta.weight(.medium))
                                    .foregroundStyle(Color.reviewTint)
                                Text("\u{201C}\(sentence.text.prefix(110))\(sentence.text.count > 110 ? "\u{2026}" : "")\u{201D}")
                                    .font(.example)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                rewriteControls(for: sentence.text, rewrite: .split, label: "Split it")
                            }
                        }
                    }
                }
                if !stats.passives.isEmpty, Settings.shows(.passive) {
                    section("Possible passive voice", divider: false) {
                        ForEach(stats.passives, id: \.self) { phrase in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(phrase).font(.pill)
                                if let sentence = stats.sentence(containing: phrase) {
                                    rewriteControls(for: sentence, rewrite: .active, label: "Make it active")
                                }
                            }
                        }
                    }
                }
                if stats.sentences >= 3, Settings.shows(.rhythm) {
                    section("Sentence rhythm", divider: false) { rhythm }
                }
            }

            // Style: habits worth a look, closed until opened.
            if hasStyleNotes {
                let open = viewModel.isOpenNotesGroup("style")
                groupHeader("Style", count: nil, open: open, summary: styleSummary) { viewModel.toggleNotesGroup("style") }
                if open {
                    if !weakWords.isEmpty {
                        section("Weak words", divider: false) {
                            weakWords.enumerated().reduce(Text("")) { text, element in
                                let (index, item) = element
                                return text + Text(index == 0 ? "" : "  \u{B7}  ").foregroundColor(.secondary)
                                    + Text(item.word).font(.pill) + Text(" " + item.tags.joined(separator: ", ")).font(.pillLabel).foregroundColor(.secondary)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if !stats.repeated.isEmpty, Settings.shows(.repeated) {
                        section("Repeated words", divider: false) {
                            wordList(stats.repeated.map { "\($0.word) \u{D7}\($0.count)" })
                        }
                    }
                    if !viewModel.crutches.isEmpty {
                        section("Your crutch words", divider: false) {
                            wordList(viewModel.crutches.map { "\($0.word) (replaced \($0.count)\u{D7})" })
                        }
                    }
                    if !viewModel.style.longParagraphs.isEmpty || !viewModel.style.ingWords.isEmpty {
                        section("Paragraphs and -ing forms", divider: false) { styleOtherControls }
                    }
                    if !viewModel.fiction.isEmpty {
                        section("Fiction", divider: false) { fictionControls }
                    }
                }
            }

            if !hasMistakes, !hasClarityNotes, !hasStyleNotes {
                VStack(alignment: .leading, spacing: 0) {
                    Divider().padding(.horizontal, 22)
                    Label("No issues found", systemImage: "checkmark.circle.fill")
                        .font(.definition.weight(.medium))
                        .foregroundStyle(Color.fitTint)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .help("Checked for typos, grammar, mixed spellings, wordy phrases, hard sentences, passive voice, weak words and repeated words.")
                }
            }
            Divider().padding(.horizontal, 22)
            TextLink(copiedNotes ? "Copied" : "Copy notes as Markdown", muted: copiedNotes, action: copyNotes)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
        }
        .padding(.bottom, 6)
        // The popup view is reused for the next passage.
        .onChange(of: stats) { _, _ in copiedNotes = false }
    }

    /// Puts the notes on the clipboard as Markdown, for a review comment
    /// or a message.
    private func copyNotes() {
        let report = NotesReport.markdown(
            stats: stats, typos: viewModel.typos, grammar: viewModel.grammar, consistency: viewModel.consistency,
            style: viewModel.style, fiction: viewModel.fiction, targetGrade: Settings.targetGrade, shows: Settings.shows
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        copiedNotes = true
    }

    /// A bar per sentence, as tall as it is long; long sentences stand
    /// out in another color, and a flat run is named under the bars.
    @ViewBuilder
    private var rhythm: some View {
        // Both are worked out from every sentence, so once per drawing,
        // not once per bar.
        let lengths = stats.sentenceLengths
        let run = stats.evenRun
        let longest = max(lengths.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(lengths.enumerated()), id: \.offset) { index, length in
                RoundedRectangle(cornerRadius: 2)
                    .fill(length > TextStats.longSentenceWords ? Color.reviewTint : Color.secondary.opacity(run?.contains(index) == true ? 0.2 : 0.4))
                    .frame(maxWidth: 14)
                    .frame(height: max(3, 44 * Settings.textScale * CGFloat(length) / CGFloat(longest)))
                    .help("\(length) words: \(stats.sentenceTexts[index])")
            }
        }
        .frame(height: 44 * Settings.textScale, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sentence lengths in words")
        .accessibilityValue(lengths.map(String.init).joined(separator: ", "))
        Text(rhythmNote(lengths, run: run))
            .font(.recentMeta)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func rhythmNote(_ lengths: [Int], run: ClosedRange<Int>?) -> String {
        var note = "Shortest \(lengths.min() ?? 0), longest \(lengths.max() ?? 0) words."
        if let run { note += " Sentences \(run.lowerBound + 1) to \(run.upperBound + 1) are about the same length, which can read flat." }
        for start in stats.repeatedStarts {
            note += " \u{201C}\(start.word.prefix(1).uppercased() + start.word.dropFirst())\u{201D} starts \(start.count) of \(lengths.count) sentences."
        }
        return note
    }

    /// Counts, reading time and the reading grade in one line.
    private var summary: String {
        let minutes = stats.readingMinutes < 1 ? "under a minute" : "\(Int(stats.readingMinutes.rounded())) min"
        let average = stats.sentences > 0 ? Double(stats.words) / Double(stats.sentences) : 0
        return "\(stats.words) words \u{B7} \(stats.sentences) sentence\(stats.sentences == 1 ? "" : "s") \u{B7} "
            + "\(String(format: "%.0f", average)) words per sentence \u{B7} \(minutes) to read \u{B7} \(gradeLabel)"
    }

    /// Each sentence that is hard to read, once, with every reason: over
    /// 25 words, above the target grade, over the style rules' limit.
    private var hardSentenceNotes: [(text: String, reasons: [String])] {
        var order: [String] = []
        var reasons: [String: [String]] = [:]
        func add(_ text: String, _ reason: String) {
            if reasons[text] == nil { order.append(text) }
            reasons[text, default: []].append(reason)
        }
        if Settings.shows(.longSentences) { for sentence in stats.longSentences { add(sentence.text, "\(sentence.words) words") } }
        for sentence in hardSentences { add(sentence.text, "grade \(Int(sentence.grade.rounded())), above your target") }
        if let limit = viewModel.style.sentenceLimit {
            for sentence in viewModel.style.longSentences { add(sentence, "over your \(limit)-word rule") }
        }
        return order.map { ($0, reasons[$0] ?? []) }
    }

    /// Adverbs and hedges together, each word once with what it is
    /// ("really: adverb, hedge"), in order of first use.
    private var weakWords: [(word: String, tags: [String])] {
        var items: [(word: String, tags: [String])] = []
        func add(_ word: String, _ tag: String) {
            if let index = items.firstIndex(where: { $0.word.lowercased() == word.lowercased() }) {
                items[index].tags.append(tag)
            } else {
                items.append((word, [tag]))
            }
        }
        if Settings.shows(.adverbs) { for adverb in stats.adverbs { add(adverb, "adverb") } }
        if Settings.shows(.hedges) { for hedge in stats.hedges { add(hedge.word, hedge.count > 1 ? "hedge \u{D7}\(hedge.count)" : "hedge") } }
        return items
    }

    /// "Above your target of 8" in amber, or "within your target of 8" in
    /// green, after the summary when a target is set.
    private var gradeTarget: Text {
        guard let target = Settings.targetGrade else { return Text("") }
        return stats.grade > Double(target)
            ? Text(" \u{B7} above your target of \(target)").foregroundColor(.reviewTint)
            : Text(" \u{B7} within your target of \(target)").foregroundColor(.fitTint)
    }

    /// The sentences above the target grade, if one is set.
    private var hardSentences: [(text: String, grade: Double)] {
        Settings.targetGrade.map { stats.sentences(above: Double($0)) } ?? []
    }

    private var gradeLabel: String {
        let grade = stats.grade
        let reader = switch grade {
        case ..<6: "very easy to read"
        case ..<9: "plain English, easy for most readers"
        case ..<13: "fairly difficult, high-school level"
        default: "difficult, college level"
        }
        return "grade \(String(format: "%.1f", grade)), \(reader)"
    }

    /// Why a tool cannot run on this selection, or nil when it can.
    /// Rewrite needs one sentence (its transitions work without the
    /// model), Check and Translate the on-device frameworks.
    private func unavailableReason(_ tool: PopupViewModel.PassageTool) -> String? {
        switch tool {
        case .rewrite: reframeSentence == nil ? "Select one sentence to rewrite it." : nil
        case .check: WritingModel.isAvailable ? nil : "Needs Apple Intelligence (macOS 26 or later)."
        case .text: viewModel.canReplace && !TextTool.useful(for: viewModel.selectionText ?? "").isEmpty
            ? nil : "Nothing to change: the case and quotes are already consistent."
        case .translate: Translator.isAvailable ? nil : "Needs macOS 26 or later."
        }
    }

    /// A chip per tool; one that cannot run here is shown dimmed with the
    /// reason, so the row does not change from one selection to the next.
    /// The open tool shows its controls below the row.
    @ViewBuilder
    private var toolControls: some View {
        HStack(spacing: 6) {
            ForEach(PopupViewModel.PassageTool.allCases, id: \.self) { tool in
                let open = viewModel.openTool == tool
                let reason = unavailableReason(tool)
                Button(action: { viewModel.openTool = open ? nil : tool }) {
                    ActionChip(title: tool.rawValue, isOn: open)
                }
                .buttonStyle(.plain)
                .disabled(reason != nil)
                .opacity(reason == nil ? 1 : 0.55)
                .help(reason ?? Self.toolHelp[tool] ?? "")
                .accessibilityValue(reason ?? "")
            }
        }
        // Why a tool is dimmed, in words and not only in a tooltip.
        let reasons = PopupViewModel.PassageTool.allCases.compactMap { tool in unavailableReason(tool).map { "\(tool.rawValue): \($0)" } }
        if viewModel.openTool == nil, !reasons.isEmpty {
            Text(reasons.joined(separator: " "))
                .font(.recentMeta)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        switch viewModel.openTool {
        case .rewrite:
            if let sentence = reframeSentence {
                if WritingModel.isAvailable {
                    toolLabel("Reframe")
                    reframeControls(for: sentence, kinds: WritingModel.Rewrite.reframes)
                    toolLabel("Add a sentence after it")
                    reframeControls(for: sentence, kinds: WritingModel.Rewrite.expansions)
                    Text("Check any fact it adds.").font(.recentMeta).foregroundStyle(.secondary)
                }
                toolLabel("Start with a transition")
                transitionControls(for: sentence)
            }
        case .check:
            toolLabel("How it reads")
            toneControls
            if stats.sentences > 1 {
                toolLabel("Main point")
                mainPointControls
            }
        case .text: TextToolControls(viewModel: viewModel)
        case .translate: translateControls
        case nil: EmptyView()
        }
    }

    private static let toolHelp: [PopupViewModel.PassageTool: String] = [
        .rewrite: "Reframe the sentence, add one after it, or start it with a transition",
        .check: "How the text reads to others, and its main point",
        .text: "Title case, sentence case, quotes and line breaks",
        .translate: "Translate the selection on this Mac",
    ]

    private func toolLabel(_ title: String) -> some View {
        Text(title)
            .font(.recentMeta.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.top, 6)
    }

    /// A group's title row: Mistakes, Clarity, Style. Style opens and
    /// closes; while closed it names what is inside.
    private func groupHeader(_ title: String, count: Int?, open: Bool, summary: String? = nil, toggle: (() -> Void)? = nil) -> some View {
        let row = HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.phrase)
                .foregroundStyle(.primary)
            if let count, count > 0 {
                Text("\(count)")
                    .font(.recentMeta.weight(.semibold))
                    .foregroundStyle(Color.reviewTint)
            }
            if !open, let summary {
                Text(summary)
                    .font(.recentMeta)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if toggle != nil {
                Image(systemName: open ? "chevron.down" : "chevron.right")
                    .font(.icon(10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        return VStack(alignment: .leading, spacing: 0) {
            Divider().padding(.horizontal, 22)
            Group {
                if let toggle {
                    Button(action: toggle) { row }
                        .buttonStyle(.plain)
                        .accessibilityValue(open ? "expanded" : "collapsed")
                } else {
                    row.accessibilityElement(children: .combine)
                }
            }
            .accessibilityAddTraits(.isHeader)
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 4)
        }
    }

    private var hasMistakes: Bool {
        !viewModel.typos.isEmpty || !viewModel.grammar.isEmpty || !viewModel.consistency.isEmpty || !viewModel.style.words.isEmpty || !stats.wordy.isEmpty
    }

    private var hasClarityNotes: Bool {
        !hardSentenceNotes.isEmpty || (!stats.passives.isEmpty && Settings.shows(.passive)) || (stats.sentences >= 3 && Settings.shows(.rhythm))
    }

    private var hasStyleNotes: Bool { !styleParts.isEmpty }

    /// The kinds of style note the passage has, named for the closed
    /// Style group's summary.
    private var styleParts: [String] {
        var parts: [String] = []
        if !weakWords.isEmpty { parts.append("weak words") }
        if !stats.repeated.isEmpty, Settings.shows(.repeated) { parts.append("repeated words") }
        if !viewModel.crutches.isEmpty { parts.append("crutch words") }
        if !viewModel.style.longParagraphs.isEmpty || !viewModel.style.ingWords.isEmpty { parts.append("style rules") }
        if !viewModel.fiction.isEmpty { parts.append("fiction") }
        return parts
    }

    private var styleSummary: String { styleParts.joined(separator: ", ") }

    private func section(_ title: String, divider: Bool = true, @ViewBuilder content: () -> some View) -> some View {
        let guide = Guides.text(for: title)
        let guideOpen = viewModel.openGuides.contains(title)
        return VStack(alignment: .leading, spacing: 0) {
            if divider { Divider().padding(.horizontal, 22) }
            VStack(alignment: .leading, spacing: 8) {
                NoteSectionHeader(title: title, guide: guide, isOpen: guideOpen) {
                    if guideOpen { viewModel.openGuides.remove(title) } else { viewModel.openGuides.insert(title) }
                }
                if guideOpen, let guide {
                    Text(guide)
                        .font(.recentMeta)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 2)
                }
                content()
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 12)
        }
    }

    /// The selection when it is one sentence, which can be reframed.
    private var reframeSentence: String? {
        stats.sentenceTexts.count == 1 ? stats.sentenceTexts[0] : nil
    }

    /// A link that asks for a rewrite of `sentence`, then the suggestion
    /// with a button that puts it into the passage in place of the
    /// original sentence.
    @ViewBuilder
    private func rewriteControls(for sentence: String, rewrite: WritingModel.Rewrite, label: String) -> some View {
        let key = RewriteKey(sentence: sentence, rewrite: rewrite)
        if viewModel.rewrites[key] != nil {
            rewriteResult(key)
        } else if WritingModel.isAvailable {
            TextLink(viewModel.rewriting.contains(key) ? "Rewriting\u{2026}" : label) { viewModel.onRewrite(key) }
        }
    }

    @ViewBuilder
    private func rewriteResult(_ key: RewriteKey) -> some View {
        if let suggestion = viewModel.rewrites[key] {
            if suggestion.isEmpty {
                Text("No rewrite came back.").font(.recentMeta).foregroundStyle(.secondary)
            } else {
                Text(suggestion)
                    .font(.definition)
                    .fixedSize(horizontal: false, vertical: true)
                if viewModel.canReplace {
                    TextLink("Replace") { viewModel.onUseRewrite(key) }
                }
            }
        }
    }

    /// A button for each way to reframe the sentence, then the answers
    /// in the order of the buttons.
    @ViewBuilder
    private func reframeControls(for sentence: String, kinds: [WritingModel.Rewrite]) -> some View {
        FlowLayout(spacing: 6) {
            ForEach(kinds, id: \.self) { rewrite in
                let key = RewriteKey(sentence: sentence, rewrite: rewrite)
                Button(action: { viewModel.onRewrite(key) }) {
                    ActionChip(title: viewModel.rewriting.contains(key) ? "\(rewrite.title)\u{2026}" : rewrite.title, isOn: viewModel.rewrites[key] != nil)
                }
                .buttonStyle(.plain)
            }
        }
        ForEach(kinds.filter { viewModel.rewrites[RewriteKey(sentence: sentence, rewrite: $0)] != nil }, id: \.self) { rewrite in
            VStack(alignment: .leading, spacing: 4) {
                Text(rewrite.title)
                    .font(.recentMeta)
                    .foregroundStyle(.secondary)
                rewriteResult(RewriteKey(sentence: sentence, rewrite: rewrite))
            }
            .padding(.top, 4)
        }
    }

    /// A link that asks the on-device model how the passage reads, then
    /// its answer: the tone, and the words that set it.
    @ViewBuilder
    private var toneControls: some View {
        if let reading = viewModel.toneReading {
            if reading.tone.isEmpty {
                Text(reading.reason).font(.recentMeta).foregroundStyle(.secondary)
            } else {
                (Text("Reads as \(reading.tone). ").font(.definition.weight(.semibold)) + Text(reading.reason).font(.definition))
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            TextLink(viewModel.isCheckingTone ? "Reading\u{2026}" : "How will this come across?", action: viewModel.onCheckTone)
        }
    }

    /// A language menu and a link that translates the selection, then the
    /// translation with Replace, or how to download a missing language.
    @ViewBuilder
    private var translateControls: some View {
        HStack(spacing: 8) {
            Picker("Into", selection: $viewModel.translateTarget) {
                if viewModel.translationTargets.isEmpty {
                    Text(Translator.name(of: viewModel.translateTarget)).tag(viewModel.translateTarget)
                }
                ForEach(viewModel.translationTargets, id: \.id) { Text($0.name).tag($0.id) }
            }
            .pickerStyle(.menu)
            .fixedSize()
            .font(.recentMeta)
            TextLink(viewModel.isTranslating ? "Translating\u{2026}" : "Translate", action: viewModel.onTranslate)
        }
        .task {
            if viewModel.translationTargets.isEmpty { viewModel.translationTargets = await Translator.targets() }
        }
        switch viewModel.translation {
        case .translated(let text):
            Text(text)
                .font(.definition)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            if viewModel.canReplace, let original = viewModel.selectionText {
                TextLink("Replace") { viewModel.onReplaceSentence(original, text) }
            }
        case .notInstalled(let languages):
            Text("Download \(languages) for translation once, in System Settings > General > Language & Region > Translation Languages. After that it works offline.")
                .font(.recentMeta)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextLink("Open Language & Region", action: Translator.openLanguageSettings)
        case .failed(let reason):
            Text(reason).font(.recentMeta).foregroundStyle(.secondary)
        case nil:
            EmptyView()
        }
    }

    /// A link that asks the on-device model for the passage's main point,
    /// then the point and whether the passage leads with it.
    @ViewBuilder
    private var mainPointControls: some View {
        if let answer = viewModel.mainPoint {
            if answer.point.isEmpty {
                Text("No answer came back.").font(.recentMeta).foregroundStyle(.secondary)
            } else {
                (Text("Main point: ").font(.definition.weight(.semibold)) + Text(answer.point).font(.definition))
                    .fixedSize(horizontal: false, vertical: true)
                Text(Self.leadNote(for: answer.sentence))
                    .font(.recentMeta)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            TextLink(viewModel.isFindingMainPoint ? "Reading\u{2026}" : "What is the main point?", action: viewModel.onFindMainPoint)
        }
    }

    /// Whether the passage leads with its main point, as editors want for
    /// an email or a report.
    static func leadNote(for sentence: Int?) -> String {
        switch sentence {
        case 1: "Your first sentence states it."
        case let number?: "Sentence \(number) states it. Readers who stop early miss it; consider putting it first."
        case nil: "No sentence states it outright. Consider opening with one that does."
        }
    }

    /// A chip for each job a transition can do; the chosen job's
    /// transitions; and the sentence with the picked one, ready to go in.
    @ViewBuilder
    private func transitionControls(for sentence: String) -> some View {
        if let current = Transitions.leading(in: sentence) {
            Text("Starts with \u{201C}\(current)\u{201D}. Pick another to swap it.")
                .font(.recentMeta)
                .foregroundStyle(.secondary)
        }
        FlowLayout(spacing: 6) {
            ForEach(Transitions.groups, id: \.job) { group in
                let chosen = viewModel.transitionJob == group.job
                Button(action: {
                    viewModel.transitionJob = chosen ? nil : group.job
                    viewModel.transition = nil
                }) {
                    ActionChip(title: group.job, isOn: chosen)
                }
                .buttonStyle(.plain)
            }
        }
        if let job = viewModel.transitionJob, let phrases = Transitions.groups.first(where: { $0.job == job })?.phrases {
            FlowLayout(spacing: 6) {
                ForEach(phrases, id: \.self) { phrase in
                    let chosen = viewModel.transition == phrase
                    Button(action: { viewModel.transition = chosen ? nil : phrase }) {
                        WordChip(text: phrase, selected: chosen, checked: chosen)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 2)
        }
        if let transition = viewModel.transition {
            let new = Transitions.applying(transition, to: sentence)
            Text(new)
                .font(.definition)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            if viewModel.canReplace {
                TextLink("Replace") { viewModel.onReplaceSentence(sentence, new) }
            }
        }
    }

    /// Each typo with its suggestions; the chosen fix is filled in, and a
    /// click on it again keeps the word as it is.
    @ViewBuilder
    private var typoControls: some View {
        ForEach(viewModel.typos, id: \.word) { typo in
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(typo.word)
                    .font(.pill)
                    .strikethrough(viewModel.typoFixes[typo.word] != nil)
                    .foregroundStyle(.secondary)
                Text("\u{2192}").font(.recentMeta).foregroundStyle(.secondary).accessibilityHidden(true)
                FlowLayout(spacing: 6) {
                    ForEach(typo.suggestions, id: \.self) { suggestion in
                        let chosen = viewModel.typoFixes[typo.word] == suggestion
                        Button(action: { viewModel.typoFixes[typo.word] = chosen ? nil : suggestion }) {
                            WordChip(text: suggestion, tint: .reviewTint, selected: chosen, checked: chosen)
                        }
                        .accessibilityLabel("Change \(typo.word) to \(suggestion)")
                        .buttonStyle(.plain)
                    }
                    notATypoButton { viewModel.learn(typo: typo.word) }
                }
            }
        }
    }

    /// Each grammar mistake in a few words of its sentence, with the
    /// checker's corrections and its reason when that says more than
    /// "Consider 'an' instead".
    @ViewBuilder
    private var grammarControls: some View {
        ForEach(Array(viewModel.grammar.enumerated()), id: \.offset) { index, issue in
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Self.excerpt(of: issue))
                        .font(.pill)
                        .foregroundStyle(.secondary)
                    Text("\u{2192}").font(.recentMeta).foregroundStyle(.secondary).accessibilityHidden(true)
                    FlowLayout(spacing: 6) {
                        ForEach(issue.corrections.prefix(3), id: \.self) { correction in
                            let chosen = viewModel.grammarFixes[index] == correction
                            Button(action: { viewModel.grammarFixes[index] = chosen ? nil : correction }) {
                                WordChip(text: correction, tint: .reviewTint, selected: chosen, checked: chosen)
                            }
                            .accessibilityLabel("Change \(issue.flagged) to \(correction)")
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !issue.message.hasPrefix("Consider") {
                    Text(issue.message).font(.recentMeta).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// The flagged words with up to two words either side: "saw a apple
    /// on".
    static func excerpt(of issue: GrammarIssue) -> String {
        let ns = issue.sentence as NSString
        let before = ns.substring(to: issue.range.location).split(separator: " ").suffix(2).joined(separator: " ")
        let after = ns.substring(from: NSMaxRange(issue.range)).split(separator: " ").prefix(2).joined(separator: " ")
        return [before, issue.flagged, after].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Words spelled two ways and British with American spelling, each
    /// with the choice to make them the same; then mixed quotes, mixed
    /// spacing and acronyms not spelled out, which only get a note.
    @ViewBuilder
    private var consistencyControls: some View {
        let consistency = viewModel.consistency
        ForEach(Array(consistency.variants.enumerated()), id: \.offset) { index, forms in
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Spelled two ways:").font(.definition).foregroundStyle(.secondary)
                ForEach(forms, id: \.self) { form in
                    let chosen = viewModel.variantChoices[index] == form
                    choicePill(form, chosen: chosen) { viewModel.variantChoices[index] = chosen ? nil : form }
                }
            }
        }
        if !consistency.british.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("British: \(consistency.british.joined(separator: ", "))\nAmerican: \(consistency.american.joined(separator: ", "))")
                    .font(.definition)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text("Use").font(.definition).foregroundStyle(.secondary)
                    ForEach([("British", PopupViewModel.SpellingSystem.british), ("American", .american)], id: \.0) { title, system in
                        let chosen = viewModel.spellingSystem == system
                        choicePill(title, chosen: chosen) { viewModel.spellingSystem = chosen ? nil : system }
                    }
                }
            }
        }
        if consistency.mixedQuotes {
            Text("Straight and curly quotes are mixed.").font(.definition).foregroundStyle(.secondary)
        }
        if consistency.mixedSpacing {
            Text("Some sentences end with two spaces, some with one.").font(.definition).foregroundStyle(.secondary)
        }
        if !consistency.acronyms.isEmpty {
            Text("Not spelled out before first use: \(consistency.acronyms.joined(separator: ", "))")
                .font(.definition)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func choicePill(_ title: String, chosen: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            WordChip(text: title, tint: .reviewTint, selected: chosen, checked: chosen)
        }
        .buttonStyle(.plain)
    }

    /// The fiction notes, each kind on its own line with what it means.
    @ViewBuilder
    private var fictionControls: some View {
        let fiction = viewModel.fiction
        if let share = fiction.dialogueShare {
            Text("Dialogue: \(Int((share * 100).rounded()))% of the words.").font(.definition).foregroundStyle(.secondary)
        }
        fictionLine("Adverbs on tags", fiction.tagAdverbs, hint: "Let the line itself show how it is said.")
        fictionLine("Tags", fiction.showyTags.map { $0.count > 1 ? "\($0.word) \u{D7}\($0.count)" : $0.word },
                    hint: "Readers skip over \u{201C}said\u{201D} and \u{201C}asked\u{201D}; other tags draw the eye.")
        fictionLine("Filter words", fiction.filterWords.map { $0.count > 1 ? "\($0.word) \u{D7}\($0.count)" : $0.word },
                    hint: "\u{201C}She saw the door open\u{201D} reads closer as \u{201C}The door opened.\u{201D}")
        fictionLine("Emotions told", fiction.emotionTells, hint: "Show it through action, speech or the body.")
    }

    @ViewBuilder
    private func fictionLine(_ title: String, _ items: [String], hint: String) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                (Text("\(title): ").font(.definition.weight(.semibold)) + Text(items.joined(separator: ", ")).font(.definition))
                    .fixedSize(horizontal: false, vertical: true)
                Text(hint).font(.recentMeta).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The words that break the user's style rules, each with its fix,
    /// chosen or not like a wordy phrase's, or only marked when the rule
    /// gives none.
    @ViewBuilder
    private var styleWordControls: some View {
        let style = viewModel.style
        ForEach(style.words, id: \.phrase) { flag in
            let chosen = viewModel.phraseFixes[flag.phrase] != nil
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(flag.phrase)
                    .font(.pill)
                    .strikethrough(chosen)
                    .foregroundStyle(.secondary)
                if flag.fix.isEmpty {
                    Text("avoid").font(.pillLabel).foregroundStyle(.secondary)
                } else {
                    Text("\u{2192}").font(.recentMeta).foregroundStyle(.secondary).accessibilityHidden(true)
                    Button(action: { viewModel.phraseFixes[flag.phrase] = chosen ? nil : flag.fix }) {
                        WordChip(text: flag.fix, tint: .reviewTint, selected: chosen, checked: chosen)
                    }
                    .accessibilityLabel("Change \(flag.phrase) to \(flag.fix)")
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Paragraphs over the style rules' limit and -ing forms.
    @ViewBuilder
    private var styleOtherControls: some View {
        let style = viewModel.style
        ForEach(style.longParagraphs, id: \.number) { paragraph in
            Text("Paragraph \(paragraph.number) has \(paragraph.sentences) sentences.").font(.definition).foregroundStyle(.secondary)
        }
        if !style.ingWords.isEmpty {
            Text("-ing forms: \(style.ingWords.joined(separator: ", "))")
                .font(.definition)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Each wordy phrase or cliche with its fix ("remove" when it can go),
    /// chosen or not like a typo's fix; a cliche with no plainer wording
    /// is only marked.
    @ViewBuilder
    private var phraseControls: some View {
        ForEach(stats.wordy, id: \.phrase) { flag in
            let chosen = viewModel.phraseFixes[flag.phrase] != nil
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(flag.phrase)
                    .font(.pill)
                    .strikethrough(chosen)
                    .foregroundStyle(.secondary)
                if flag.isCliche || flag.isHiddenVerb {
                    Text(flag.isCliche ? "clich\u{E9}" : "hidden verb").font(.pillLabel).foregroundStyle(.secondary)
                }
                if !flag.isCliche || !flag.fix.isEmpty {
                    Text("\u{2192}").font(.recentMeta).foregroundStyle(.secondary).accessibilityHidden(true)
                    Button(action: { viewModel.phraseFixes[flag.phrase] = chosen ? nil : flag.fix }) {
                        WordChip(text: flag.fix.isEmpty ? "remove" : flag.fix, tint: .reviewTint, selected: chosen, checked: chosen, italic: flag.fix.isEmpty)
                    }
                    .accessibilityLabel(flag.fix.isEmpty ? "Remove \(flag.phrase)" : "Change \(flag.phrase) to \(flag.fix)")
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// One button for the typo and phrase fixes together, as the first
    /// paste closes the popup.
    @ViewBuilder
    private var applyFixesButton: some View {
        if viewModel.canReplace, viewModel.hasFixes {
            Button(action: viewModel.onApplyFixes) {
                Label(viewModel.fixesLabel, systemImage: "checkmark.circle.fill")
                    .font(.link)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.accentColor, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private func wordList(_ words: [String]) -> some View {
        Text(words.joined(separator: "  \u{B7}  "))
            .font(.pill)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A link that adds a flagged word (a name, a term) to the Mac's spelling
/// dictionary, so it is not flagged again here or in other apps.
func notATypoButton(action: @escaping () -> Void) -> some View {
    TextLink("Not a typo", muted: true, action: action)
        .frame(minHeight: 24)
        .help("Adds the word to your Mac\u{2019}s spelling dictionary, so no app flags it again")
}

/// A chip for each text tool that would change the selection (Title
/// Case, Sentence case, quotes, Join lines), then the changed text with a
/// button that puts it in place of the selection.
struct TextToolControls: View {
    @ObservedObject var viewModel: PopupViewModel

    var body: some View {
        if let text = viewModel.selectionText, viewModel.canReplace {
            FlowLayout(spacing: 6) {
                ForEach(TextTool.useful(for: text), id: \.self) { tool in
                    let chosen = viewModel.textTool == tool
                    Button(action: { viewModel.textTool = chosen ? nil : tool }) {
                        ActionChip(title: tool.rawValue, isOn: chosen)
                    }
                    .buttonStyle(.plain)
                }
            }
            if let tool = viewModel.textTool {
                let new = tool.apply(to: text)
                Text(new)
                    .font(.definition)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                TextLink("Replace") { viewModel.onReplaceSentence(text, new) }
            }
        }
    }
}
