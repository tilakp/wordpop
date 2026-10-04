import AppKit
import SwiftUI

/// One multiple-choice question about a starred word.
struct PracticeQuestion: Equatable {
    enum Kind: Equatable { case definition, blank }

    let kind: Kind
    /// The definition to match, or a sentence with the word blanked out.
    let prompt: String
    let choices: [String]
    let answer: String
}

enum PracticeQuiz {
    /// A question with `answer` among `distractors`, in random order.
    static func question(_ kind: PracticeQuestion.Kind, prompt: String, answer: String, distractors: [String]) -> PracticeQuestion {
        let others = Array(distractors.filter { $0.lowercased() != answer.lowercased() }.prefix(3))
        return PracticeQuestion(kind: kind, prompt: prompt, choices: (others + [answer]).shuffled(), answer: answer)
    }

    /// `sentence` with the word (or a form of it: "planned" for "plan")
    /// replaced by a blank, or nil when the word is not in it.
    static func blanked(_ sentence: String, word: String) -> String? {
        let stem = String(word.lowercased().prefix(max(3, word.count - 2)))
        var result = sentence
        var found = false
        let ns = sentence as NSString
        let regex = try! NSRegularExpression(pattern: "[\\p{L}']+")
        for match in regex.matches(in: sentence, range: NSRange(location: 0, length: ns.length)).reversed() {
            let token = ns.substring(with: match.range)
            guard token.lowercased().hasPrefix(stem), let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: "_____")
            found = true
        }
        return found ? result : nil
    }
}

/// Runs a practice round over the starred words: definition questions,
/// and, with Apple Intelligence, fill-in-the-blank questions on every
/// other turn.
final class PracticeModel: ObservableObject {
    @Published private(set) var question: PracticeQuestion?
    @Published private(set) var chosen: String?
    @Published private(set) var asked = 0
    @Published private(set) var correct = 0
    @Published private(set) var isLoading = false

    private var queue: [String] = []

    var words: [String] { StarredWords.shared.words }

    func start() {
        asked = 0
        correct = 0
        queue = words.shuffled()
        next()
    }

    func choose(_ choice: String) {
        guard chosen == nil, let question else { return }
        chosen = choice
        asked += 1
        if choice == question.answer { correct += 1 }
    }

    func next() {
        chosen = nil
        guard !words.isEmpty else { question = nil; return }
        if queue.isEmpty { queue = words.shuffled() }
        let word = queue.removeFirst()
        let distractors = distractors(for: word)
        guard let definition = DictionaryLookup.firstDefinition(of: word)?.text else { next(); return }
        if WritingModel.isAvailable, asked % 2 == 1 {
            isLoading = true
            question = nil
            Task { @MainActor in
                let sentences = await WritingModel.examples(of: word, partOfSpeech: nil, definition: definition)
                self.isLoading = false
                if let blank = sentences.lazy.compactMap({ PracticeQuiz.blanked($0, word: word) }).first {
                    self.question = PracticeQuiz.question(.blank, prompt: blank, answer: word, distractors: distractors)
                } else {
                    self.question = PracticeQuiz.question(.definition, prompt: definition, answer: word, distractors: distractors)
                }
            }
        } else {
            question = PracticeQuiz.question(.definition, prompt: definition, answer: word, distractors: distractors)
        }
    }

    /// Other starred words first, then common words of similar frequency.
    private func distractors(for word: String) -> [String] {
        var others = words.filter { $0.lowercased() != word.lowercased() }.shuffled()
        if others.count < 3 {
            let rank = Database.ranks(of: [word])[word.lowercased()] ?? 20_000
            others += Database.randomWords(nearRank: rank, count: 3 - others.count + 2).filter { $0.lowercased() != word.lowercased() }
        }
        return others
    }
}

struct PracticeView: View {
    @ObservedObject var model: PracticeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Practice").font(.headword)
                Spacer()
                if model.asked > 0 {
                    Text("\(model.correct) of \(model.asked) right")
                        .font(.recentMeta)
                        .foregroundStyle(.secondary)
                }
            }
            if model.words.isEmpty {
                Text("Star words in the popup (\u{2318}D) to practice them here.")
                    .font(.definition)
                    .foregroundStyle(.secondary)
            } else if model.isLoading {
                Text("Writing a sentence\u{2026}").font(.definition).foregroundStyle(.secondary)
            } else if let question = model.question {
                Text(question.kind == .definition ? "Which word means:" : "Which word fills the blank?")
                    .font(.sectionLabel)
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(question.kind == .definition ? question.prompt : "\u{201C}\(question.prompt)\u{201D}")
                    .font(question.kind == .definition ? .definition : .example)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 8) {
                    ForEach(question.choices, id: \.self) { choice in
                        Button(action: { model.choose(choice) }) {
                            Text(choice)
                                .font(.pill)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(fill(for: choice, in: question)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if model.chosen != nil {
                    HStack {
                        Text(model.chosen == question.answer ? "Right." : "It was \u{201C}\(question.answer)\u{201D}.")
                            .font(.definition)
                        Spacer()
                        Button("Next") { model.next() }.keyboardShortcut(.defaultAction)
                    }
                }
            }
        }
        .padding(22)
        .frame(width: 420)
        .background(Color.popupPage)
    }

    private func fill(for choice: String, in question: PracticeQuestion) -> Color {
        guard let chosen = model.chosen else { return Color.primary.opacity(0.06) }
        if choice == question.answer { return Color.green.opacity(0.25) }
        if choice == chosen { return Color.red.opacity(0.22) }
        return Color.primary.opacity(0.04)
    }
}

final class PracticeWindowController: NSWindowController {

    convenience init() {
        let practice = PracticeModel()
        let window = NSWindow(contentViewController: NSHostingController(rootView: PracticeView(model: practice)))
        window.title = "WordPop Practice"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        self.init(window: window)
        practiceModel = practice
    }

    private var practiceModel: PracticeModel?

    func show() {
        practiceModel?.start()
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
