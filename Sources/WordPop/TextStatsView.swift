import SwiftUI

/// The popup's view of a selected passage: counts and reading grade at the
/// top, then the sentences and words worth a second look.
struct TextStatsView: View {
    let stats: TextStats
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Selected text")
                    .font(.headword)
                    .tracking(-0.3)
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark.circle.fill") }
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

            section("Reading grade", tint: .synonymTint) {
                Text(gradeLabel)
                    .font(.definition)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !stats.longSentences.isEmpty {
                section("Long sentences (over \(TextStats.longSentenceWords) words)", tint: .antonymTint) {
                    ForEach(Array(stats.longSentences.prefix(3).enumerated()), id: \.offset) { _, sentence in
                        Text("\(sentence.words) words: \u{201C}\(sentence.text.prefix(90))\(sentence.text.count > 90 ? "\u{2026}" : "")\u{201D}")
                            .font(.example)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if !stats.passives.isEmpty {
                section("Possible passive voice", tint: .strongerTint) { wordList(stats.passives) }
            }
            if !stats.adverbs.isEmpty {
                section("Adverbs", tint: .rhymeTint) { wordList(stats.adverbs) }
            }
            if !stats.repeated.isEmpty {
                section("Repeated words", tint: .confusedTint) {
                    wordList(stats.repeated.map { "\($0.word) \u{D7}\($0.count)" })
                }
            }
            if stats.longSentences.isEmpty, stats.passives.isEmpty, stats.adverbs.isEmpty, stats.repeated.isEmpty {
                section("Notes", tint: .fitTint) {
                    Text("No long sentences, passive voice, -ly adverbs or repeated words.")
                        .font(.definition)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.bottom, 6)
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

    private func wordList(_ words: [String]) -> some View {
        Text(words.joined(separator: "  \u{B7}  "))
            .font(.pill)
            .fixedSize(horizontal: false, vertical: true)
    }
}
