import SwiftUI

/// The popup's view of a selected passage: counts and reading grade at the
/// top, then the sentences and words worth a second look.
struct TextStatsView: View {
    let stats: TextStats
    @ObservedObject var viewModel: PopupViewModel

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

            Text(summary)
                .font(.forms)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 22)
                .padding(.bottom, 14)

            if let sentence = reframeSentence, WritingModel.isAvailable {
                section("Reframe", tint: .fitTint) { reframeControls(for: sentence) }
            }
            if let sentence = reframeSentence {
                section("Transitions", tint: .collocationTint) { transitionControls(for: sentence) }
            }
            if !viewModel.typos.isEmpty {
                section("Spelling", tint: .spellingTint) {
                    typoControls
                    if viewModel.grammar.isEmpty, viewModel.consistency.isEmpty, stats.wordy.isEmpty { applyFixesButton }
                }
            }
            if !viewModel.grammar.isEmpty {
                section("Grammar", tint: .spellingTint) {
                    grammarControls
                    if viewModel.consistency.isEmpty, stats.wordy.isEmpty { applyFixesButton }
                }
            }
            if !viewModel.consistency.isEmpty {
                section("Consistency", tint: .confusedTint) {
                    consistencyControls
                    if stats.wordy.isEmpty { applyFixesButton }
                }
            }
            if !stats.wordy.isEmpty {
                section("Wordy phrases and clich\u{E9}s", tint: .strongerTint) {
                    phraseControls
                    applyFixesButton
                }
            }
            section("Reading grade", tint: .synonymTint) {
                Text(gradeLabel)
                    .font(.definition)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if stats.sentences >= 3 {
                section("Sentence rhythm", tint: .synonymTint) { rhythm }
            }
            if !stats.longSentences.isEmpty {
                section("Long sentences (over \(TextStats.longSentenceWords) words)", tint: .antonymTint) {
                    ForEach(Array(stats.longSentences.prefix(3).enumerated()), id: \.offset) { _, sentence in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(sentence.words) words: \u{201C}\(sentence.text.prefix(90))\(sentence.text.count > 90 ? "\u{2026}" : "")\u{201D}")
                                .font(.example)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            rewriteControls(for: sentence.text, rewrite: .split, label: "Split it")
                        }
                    }
                }
            }
            if !stats.passives.isEmpty {
                section("Possible passive voice", tint: .strongerTint) {
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
            if !stats.adverbs.isEmpty {
                section("Adverbs", tint: .rhymeTint) { wordList(stats.adverbs) }
            }
            if !stats.repeated.isEmpty {
                section("Repeated words", tint: .confusedTint) {
                    wordList(stats.repeated.map { "\($0.word) \u{D7}\($0.count)" })
                }
            }
            if stats.longSentences.isEmpty, stats.passives.isEmpty, stats.adverbs.isEmpty, stats.repeated.isEmpty, viewModel.typos.isEmpty,
               stats.wordy.isEmpty, viewModel.grammar.isEmpty, viewModel.consistency.isEmpty {
                section("Notes", tint: .fitTint) {
                    Text("No typos, grammar mistakes, mixed spellings, wordy phrases, long sentences, passive voice, -ly adverbs or repeated words.")
                        .font(.definition)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.bottom, 6)
    }

    /// A bar per sentence, as tall as it is long; long sentences stand
    /// out in another color, and a flat run is named under the bars.
    @ViewBuilder
    private var rhythm: some View {
        let lengths = stats.sentenceLengths
        let longest = max(lengths.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(lengths.enumerated()), id: \.offset) { index, length in
                RoundedRectangle(cornerRadius: 2)
                    .fill(length > TextStats.longSentenceWords ? Color.antonymTint : Color.synonymTint.opacity(stats.evenRun?.contains(index) == true ? 0.4 : 0.8))
                    .frame(maxWidth: 14)
                    .frame(height: max(3, 44 * CGFloat(length) / CGFloat(longest)))
                    .help("\(length) words: \(stats.sentenceTexts[index])")
            }
        }
        .frame(height: 44, alignment: .bottom)
        Text(rhythmNote(lengths))
            .font(.recentMeta)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func rhythmNote(_ lengths: [Int]) -> String {
        let range = "Shortest \(lengths.min() ?? 0), longest \(lengths.max() ?? 0) words."
        guard let run = stats.evenRun else { return range }
        return range + " Sentences \(run.lowerBound + 1) to \(run.upperBound + 1) are about the same length, which can read flat."
    }

    private var summary: String {
        let minutes = stats.readingMinutes < 1 ? "under a minute" : "\(Int(stats.readingMinutes.rounded())) min"
        let average = stats.sentences > 0 ? Double(stats.words) / Double(stats.sentences) : 0
        return "\(stats.words) words \u{B7} \(stats.sentences) sentence\(stats.sentences == 1 ? "" : "s") \u{B7} "
            + "\(String(format: "%.0f", average)) words per sentence \u{B7} \(minutes) to read"
    }

    private var gradeLabel: String {
        let grade = stats.grade
        let reader = switch grade {
        case ..<6: "very easy to read"
        case ..<9: "plain English, easy for most readers"
        case ..<13: "fairly difficult, high-school level"
        default: "difficult, college level"
        }
        return "Grade \(String(format: "%.1f", grade)): \(reader)."
    }

    private func section(_ title: String, tint: Color, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().padding(.horizontal, 22)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.sectionLabel)
                    .tracking(1.2)
                    .foregroundStyle(tint)
                    .textCase(.uppercase)
                content()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
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
            Button(action: { viewModel.onRewrite(key) }) {
                Text(viewModel.rewriting.contains(key) ? "Rewriting\u{2026}" : label)
                    .font(.recentMeta)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func rewriteResult(_ key: RewriteKey) -> some View {
        if let suggestion = viewModel.rewrites[key] {
            if suggestion.isEmpty {
                Text("No rewrite came back.").font(.recentMeta).foregroundStyle(.tertiary)
            } else {
                Text(suggestion)
                    .font(.definition)
                    .fixedSize(horizontal: false, vertical: true)
                if viewModel.canReplace {
                    Button("Replace") { viewModel.onUseRewrite(key) }
                        .font(.recentMeta)
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }

    /// A button for each way to reframe the sentence, then the answers
    /// in the order of the buttons.
    @ViewBuilder
    private func reframeControls(for sentence: String) -> some View {
        let kinds = WritingModel.Rewrite.reframes
        FlowLayout(spacing: 6) {
            ForEach(kinds, id: \.self) { rewrite in
                let key = RewriteKey(sentence: sentence, rewrite: rewrite)
                Button(action: { viewModel.onRewrite(key) }) {
                    Text(viewModel.rewriting.contains(key) ? "\(rewrite.title)\u{2026}" : rewrite.title)
                        .font(.recentMeta)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Color.fitTint.opacity(viewModel.rewrites[key] != nil ? 0.28 : 0.12))
                        .clipShape(Capsule())
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
                    Text(group.job)
                        .font(.recentMeta)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Color.collocationTint.opacity(chosen ? 0.3 : 0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        if let job = viewModel.transitionJob, let phrases = Transitions.groups.first(where: { $0.job == job })?.phrases {
            FlowLayout(spacing: 6) {
                ForEach(phrases, id: \.self) { phrase in
                    let chosen = viewModel.transition == phrase
                    Button(action: { viewModel.transition = chosen ? nil : phrase }) {
                        Text(phrase)
                            .font(.pill)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 2)
                            .background(Color.collocationTint.opacity(chosen ? 0.28 : 0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(chosen ? Color.collocationTint : Color.collocationTint.opacity(0.25)))
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
                Button("Replace") { viewModel.onReplaceSentence(sentence, new) }
                    .font(.recentMeta)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
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
                Text("\u{2192}").font(.recentMeta).foregroundStyle(.tertiary)
                FlowLayout(spacing: 6) {
                    ForEach(typo.suggestions, id: \.self) { suggestion in
                        let chosen = viewModel.typoFixes[typo.word] == suggestion
                        Button(action: { viewModel.typoFixes[typo.word] = chosen ? nil : suggestion }) {
                            Text(suggestion)
                                .font(.pill)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 2)
                                .background(Color.spellingTint.opacity(chosen ? 0.28 : 0.08))
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(chosen ? Color.spellingTint : Color.spellingTint.opacity(0.25)))
                        }
                        .buttonStyle(.plain)
                    }
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
                    Text("\u{2192}").font(.recentMeta).foregroundStyle(.tertiary)
                    FlowLayout(spacing: 6) {
                        ForEach(issue.corrections.prefix(3), id: \.self) { correction in
                            let chosen = viewModel.grammarFixes[index] == correction
                            Button(action: { viewModel.grammarFixes[index] = chosen ? nil : correction }) {
                                Text(correction)
                                    .font(.pill)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 2)
                                    .background(Color.spellingTint.opacity(chosen ? 0.28 : 0.08))
                                    .clipShape(Capsule())
                                    .overlay(Capsule().strokeBorder(chosen ? Color.spellingTint : Color.spellingTint.opacity(0.25)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if !issue.message.hasPrefix("Consider") {
                    Text(issue.message).font(.recentMeta).foregroundStyle(.tertiary)
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
            Text(title)
                .font(.pill)
                .padding(.horizontal, 9)
                .padding(.vertical, 2)
                .background(Color.confusedTint.opacity(chosen ? 0.28 : 0.08))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(chosen ? Color.confusedTint : Color.confusedTint.opacity(0.25)))
        }
        .buttonStyle(.plain)
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
                if flag.isCliche {
                    Text("clich\u{E9}").font(.pillLabel).foregroundStyle(.tertiary)
                }
                if !flag.isCliche || !flag.fix.isEmpty {
                    Text("\u{2192}").font(.recentMeta).foregroundStyle(.tertiary)
                    Button(action: { viewModel.phraseFixes[flag.phrase] = chosen ? nil : flag.fix }) {
                        Text(flag.fix.isEmpty ? "remove" : flag.fix)
                            .font(.pill)
                            .italic(flag.fix.isEmpty)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 2)
                            .background(Color.strongerTint.opacity(chosen ? 0.28 : 0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(chosen ? Color.strongerTint : Color.strongerTint.opacity(0.25)))
                    }
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
            Button(viewModel.fixesLabel, action: viewModel.onApplyFixes)
                .font(.recentMeta)
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .padding(.top, 2)
        }
    }

    private func wordList(_ words: [String]) -> some View {
        Text(words.joined(separator: "  \u{B7}  "))
            .font(.pill)
            .fixedSize(horizontal: false, vertical: true)
    }
}
