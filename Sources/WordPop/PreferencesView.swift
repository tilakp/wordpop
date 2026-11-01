import SwiftUI
import AppKit

struct PreferencesView: View {
    @State private var launchAtLogin = LoginItemManager.isEnabled
    @AppStorage(Settings.textSizeKey) private var textSize = TextSize.medium
    @AppStorage(Settings.popupPlacementKey) private var popupPlacement = PopupPlacement.center
    @State private var hiddenSections = Settings.hiddenSections
    @AppStorage(StyleRules.presetKey) private var stylePreset = StyleRules.Preset.none
    @AppStorage(Settings.targetGradeKey) private var targetGrade = 0
    @AppStorage(Settings.fictionNotesKey) private var fictionNotes = false
    let onLookupShortcutChanged: (HotkeyShortcut) -> String?
    let onQuickSearchShortcutChanged: (HotkeyShortcut) -> String?

    @State private var rulesStatus = StyleRules.fileStatus()

    var body: some View {
        TabView {
            generalTab.tabItem { Label("General", systemImage: "gearshape") }
            wordPopupTab.tabItem { Label("Word Popup", systemImage: "character.book.closed") }
            passageTab.tabItem { Label("Passage Notes", systemImage: "text.alignleft") }
            styleTab.tabItem { Label("Style Rules", systemImage: "checklist") }
        }
        // Grouped forms scroll and have no height of their own.
        .frame(width: 500, height: 560)
    }

    private var generalTab: some View {
        Form {
            Section("Shortcuts") {
                ShortcutSettingRow(
                    title: "Look up the selection",
                    subtitle: "Select a word or a passage anywhere on your Mac, then press this shortcut.",
                    current: HotkeySettings.current,
                    defaultShortcut: .default,
                    onChange: { newValue in
                        if let error = onLookupShortcutChanged(newValue) { return error }
                        HotkeySettings.current = newValue
                        return nil
                    }
                )
                ShortcutSettingRow(
                    title: "Quick Search",
                    subtitle: "Opens a search bar to look up any word, without selecting text first.",
                    current: HotkeySettings.quickSearch,
                    defaultShortcut: .defaultQuickSearch,
                    onChange: { newValue in
                        if let error = onQuickSearchShortcutChanged(newValue) { return error }
                        HotkeySettings.quickSearch = newValue
                        return nil
                    }
                )
            }
            Section("Appearance") {
                Picker("Text size", selection: $textSize) {
                    ForEach(TextSize.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Popup position", selection: $popupPlacement) {
                    ForEach(PopupPlacement.allCases) { Text($0.label).tag($0) }
                }
            }
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LoginItemManager.setEnabled(newValue)
                        // Reflect what actually happened: registration can
                        // fail (e.g. running from an unstable build
                        // location), and this keeps the toggle honest.
                        launchAtLogin = LoginItemManager.isEnabled
                    }
            }
        }
        .formStyle(.grouped)
    }

    /// The popup's sections in the groups the popup shows them in.
    private static let popupGroups: [(String, [PopupSection])] = [
        ("Main card", [.fits, .synonyms, .tone]),
        ("Word choice", [.antonyms, .specific, .family, .stronger, .inclusive, .confused, .soundsLike]),
        ("Usage", [.describing, .collocations, .examples, .usage, .phrases, .origin]),
        ("Sound", [.rhymes]),
    ]

    private var wordPopupTab: some View {
        Form {
            Section {
                Text("Turn off the parts you do not use. Parts that use Apple Intelligence also skip their work when off.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(Self.popupGroups, id: \.0) { title, sections in
                Section(title) {
                    ForEach(sections) { section in
                        Toggle(section.label, isOn: shows(section.rawValue))
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private static let passageGroups: [(String, [PassageSection])] = [
        ("Mistakes", [.consistency, .wordy]),
        ("Clarity", [.longSentences, .passive, .rhythm]),
        ("Style", [.adverbs, .hedges, .repeated, .crutches]),
    ]

    private var passageTab: some View {
        Form {
            Section {
                Text("Spelling and grammar always show. A part that is off is not checked at all, so none of its fixes go in unseen.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Toggle("Tools row (Rewrite, Check, Text, Translate)", isOn: shows(PassageSection.tools.id))
            }
            ForEach(Self.passageGroups, id: \.0) { title, sections in
                Section(title) {
                    ForEach(sections) { section in
                        Toggle(section.label, isOn: shows(section.id))
                    }
                    if title == "Style" {
                        Toggle("Fiction: dialogue tags, filter words, emotions told", isOn: $fictionNotes)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var styleTab: some View {
        Form {
            Section {
                Picker("Preset", selection: $stylePreset) {
                    ForEach(StyleRules.Preset.allCases) { Text($0.label).tag($0) }
                }
                Picker("Target reading grade", selection: $targetGrade) {
                    Text("None").tag(0)
                    ForEach(5...12, id: \.self) { Text("Grade \($0)").tag($0) }
                }
            } footer: {
                Text("Notes on a passage list what breaks these rules, and sentences above the target grade.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Section("Your own rules") {
                LabeledContent("Rules file") {
                    HStack {
                        Button("Edit\u{2026}") { StyleRules.openFile() }
                        Button("Check Again") { rulesStatus = StyleRules.fileStatus() }
                    }
                }
                Text(rulesStatus)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .onAppear { rulesStatus = StyleRules.fileStatus() }
    }

    /// Whether the section with this key shows, saved as it changes.
    private func shows(_ key: String) -> Binding<Bool> {
        Binding(
            get: { !hiddenSections.contains(key) },
            set: { shown in
                if shown { hiddenSections.remove(key) } else { hiddenSections.insert(key) }
                Settings.hiddenSections = hiddenSections
            }
        )
    }
}

final class PreferencesWindowController: NSWindowController {
    convenience init(onLookupShortcutChanged: @escaping (HotkeyShortcut) -> String?, onQuickSearchShortcutChanged: @escaping (HotkeyShortcut) -> String?) {
        let view = PreferencesView(
            onLookupShortcutChanged: onLookupShortcutChanged,
            onQuickSearchShortcutChanged: onQuickSearchShortcutChanged
        )
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "WordPop Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }

    func show() {
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
