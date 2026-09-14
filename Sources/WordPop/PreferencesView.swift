import SwiftUI
import AppKit

struct PreferencesView: View {
    @State private var launchAtLogin = LoginItemManager.isEnabled
    @AppStorage(Settings.textSizeKey) private var textSize = TextSize.medium
    @AppStorage(Settings.popupPlacementKey) private var popupPlacement = PopupPlacement.center
    let onLookupShortcutChanged: (HotkeyShortcut) -> Bool
    let onQuickSearchShortcutChanged: (HotkeyShortcut) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ShortcutSettingRow(
                title: "Lookup Shortcut",
                subtitle: "Select a word anywhere on your Mac, then press this shortcut to look it up.",
                current: HotkeySettings.current,
                defaultShortcut: .default,
                onChange: { newValue in
                    guard onLookupShortcutChanged(newValue) else { return false }
                    HotkeySettings.current = newValue
                    return true
                }
            )

            Divider()

            ShortcutSettingRow(
                title: "Quick Search Shortcut",
                subtitle: "Opens a search bar to look up any word directly, without selecting text first.",
                current: HotkeySettings.quickSearch,
                defaultShortcut: .defaultQuickSearch,
                onChange: { newValue in
                    guard onQuickSearchShortcutChanged(newValue) else { return false }
                    HotkeySettings.quickSearch = newValue
                    return true
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
}

final class PreferencesWindowController: NSWindowController {
    convenience init(onLookupShortcutChanged: @escaping (HotkeyShortcut) -> Bool, onQuickSearchShortcutChanged: @escaping (HotkeyShortcut) -> Bool) {
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
