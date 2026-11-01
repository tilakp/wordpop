import AppKit
import SwiftUI

/// What the writer mostly writes, which sets the style preset, the
/// target grade and the fiction notes in one choice.
enum WriterProfile: String, CaseIterable, Identifiable {
    case everyday, student, technical, fiction

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var summary: String {
        switch self {
        case .everyday: "Emails, messages and notes. No style rules."
        case .student: "Essays and reports. Sentences above grade 10 are noted."
        case .technical: "Manuals and specs. Simplified Technical English rules, sentences above grade 9 noted."
        case .fiction: "Stories. Fiction notes on dialogue tags, filter words and emotions told."
        }
    }

    static let key = "WordPop.writerProfile"

    static var current: WriterProfile {
        UserDefaults.standard.string(forKey: key).flatMap(WriterProfile.init) ?? .everyday
    }

    /// Sets the preferences this profile stands for. Each can still be
    /// changed in Settings afterwards.
    func apply() {
        let defaults = UserDefaults.standard
        defaults.set(rawValue, forKey: Self.key)
        defaults.set(self == .technical ? StyleRules.Preset.ste.rawValue : StyleRules.Preset.none.rawValue, forKey: StyleRules.presetKey)
        defaults.set(self == .student ? 10 : self == .technical ? 9 : 0, forKey: Settings.targetGradeKey)
        defaults.set(self == .fiction, forKey: Settings.fictionNotesKey)
    }
}

/// The first-run window: the two shortcuts with a sample of each, the
/// clicks worth knowing, a writer profile, and whether WordPop can read
/// selections yet.
struct WelcomeView: View {
    let onSampleWord: () -> Void
    let onSamplePassage: () -> Void
    let onQuickSearch: () -> Void
    let onDone: () -> Void
    @State private var profile = WriterProfile.current
    @State private var trusted = AXIsProcessTrusted()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to WordPop")
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                Text("A dictionary, a thesaurus and an editor that come to the text you are writing, in any app. Everything runs on your Mac.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            step("1", "Look up a word", "Select a word in any app and press \(HotkeySettings.current.displayString).", button: "Show me", action: onSampleWord)
            step("2", "Check a passage", "Select a sentence or a paragraph and press the same shortcut for notes and one-click fixes.", button: "Show me", action: onSamplePassage)
            step("3", "Search without selecting", "Press \(HotkeySettings.quickSearch.displayString) to type a word, describe a meaning, or check a phrase.", button: "Open", action: onQuickSearch)

            VStack(alignment: .leading, spacing: 6) {
                Text("In the popup").font(.headline)
                Text("Click a word to look it up \u{B7} \u{2325}-click to put it in your text \u{B7} \u{21E7}-click to compare \u{B7} Space to hear it \u{B7} \u{2318}D to star it \u{B7} Esc to close")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("What do you write most?").font(.headline)
                Picker("What do you write most?", selection: $profile) {
                    ForEach(WriterProfile.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: profile) { _, new in new.apply() }
                Text(profile.summary + " You can change this in Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                if trusted {
                    Label("WordPop can read your selections.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Color.fitTint)
                } else {
                    Label("WordPop needs Accessibility permission to read selections.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.reviewTint)
                    Button("Open Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                Spacer()
                Button("Start Writing", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
            .font(.callout)
        }
        .padding(24)
        .frame(width: 520)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in trusted = AXIsProcessTrusted() }
    }

    private func step(_ number: String, _ title: String, _ detail: String, button: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.accentColor, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button(button, action: action)
        }
        .accessibilityElement(children: .contain)
    }
}

final class WelcomeWindowController: NSWindowController {
    static let shownKey = "WordPop.welcomeShown"

    convenience init(onSampleWord: @escaping () -> Void, onSamplePassage: @escaping () -> Void, onQuickSearch: @escaping () -> Void) {
        var close: () -> Void = {}
        let view = WelcomeView(onSampleWord: onSampleWord, onSamplePassage: onSamplePassage, onQuickSearch: onQuickSearch, onDone: { close() })
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Welcome to WordPop"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        self.init(window: window)
        close = { [weak window] in window?.close() }
    }

    func show() {
        UserDefaults.standard.set(true, forKey: Self.shownKey)
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
