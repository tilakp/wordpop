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

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ShortcutSettingRow(
                title: "Lookup Shortcut",
                subtitle: "Select a word anywhere on your Mac, then press this shortcut to look it up.",
                current: HotkeySettings.current,
                defaultShortcut: .default,
                onChange: { newValue in
                    if let error = onLookupShortcutChanged(newValue) { return error }
                    HotkeySettings.current = newValue
                    return nil
                }
            )

            Divider()

            ShortcutSettingRow(
                title: "Quick Search Shortcut",
                subtitle: "Opens a search bar to look up any word directly, without selecting text first.",
                current: HotkeySettings.quickSearch,
                defaultShortcut: .defaultQuickSearch,
                onChange: { newValue in
                    if let error = onQuickSearchShortcutChanged(newValue) { return error }
                    HotkeySettings.quickSearch = newValue
                    return nil
                }
            )

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Text Size").font(.headline)
                Picker("Text Size", selection: $textSize) {
                    ForEach(TextSize.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Popup Position").font(.headline)
                Picker("Popup Position", selection: $popupPlacement) {
                    ForEach(PopupPlacement.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Popup Sections").font(.headline)
                Text("Hide the parts of the popup you don\u{2019}t use. Hidden sections that use Apple Intelligence also skip their work.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 4) {
                    ForEach(PopupSection.allCases) { section in
                        Toggle(section.label, isOn: shows(section.rawValue))
                    }
                }
                Text("Notes on a passage").font(.subheadline).padding(.top, 6)
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 4) {
                    ForEach(PassageSection.allCases) { section in
                        Toggle(section.label, isOn: shows(section.id))
                    }
                }
                Toggle("Fiction: dialogue tags, filter words, emotions told", isOn: $fictionNotes)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Style Rules").font(.headline)
                Text("Notes on a passage list the words, long sentences and paragraphs that break these rules. Your own rules add to the preset.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Picker("Preset", selection: $stylePreset) {
                    ForEach(StyleRules.Preset.allCases) { Text($0.label).tag($0) }
                }
                Picker("Target reading grade", selection: $targetGrade) {
                    Text("None").tag(0)
                    ForEach(5...12, id: \.self) { Text("Grade \($0)").tag($0) }
                }
                Button("Edit My Rules\u{2026}", action: StyleRules.openFile)
            }

            Divider()

            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    LoginItemManager.setEnabled(newValue)
                    // Reflect what actually happened — registration can
                    // fail (e.g. running from an unstable build location),
                    // and this keeps the toggle from lying about it.
                    launchAtLogin = LoginItemManager.isEnabled
                }
        }
        .padding(20)
        .frame(width: 380)
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
        window.title = "WordPop Preferences"
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
