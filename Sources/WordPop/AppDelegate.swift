import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager!
    private var quickSearchHotkeyManager: HotkeyManager!
    private var popupController: PopupController!
    private var quickSearchController: QuickSearchController!
    private var statusItemController: StatusItemController!
    private var preferencesWindowController: PreferencesWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityPermissionIfNeeded()
        warmDatasetCachesInBackground()

        popupController = PopupController()
        quickSearchController = QuickSearchController { [weak self] word in
            let entry = DictionaryLookup.lookup(word)
            self?.popupController.show(entry: entry, near: NSEvent.mouseLocation)
        }

        hotkeyManager = HotkeyManager { [weak self] in
            self?.handleHotkey()
        }
        hotkeyManager.register(shortcut: HotkeySettings.current)

        quickSearchHotkeyManager = HotkeyManager { [weak self] in
            self?.quickSearchController.show()
        }
        quickSearchHotkeyManager.register(shortcut: HotkeySettings.quickSearch)

        statusItemController = StatusItemController(
            onPreferences: { [weak self] in self?.showPreferences() },
            onQuit: { NSApp.terminate(nil) }
        )
    }

    private func requestAccessibilityPermissionIfNeeded() {
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// The synonym/antonym/rhyme datasets are a few megabytes of JSON each;
    /// decoding them lazily on the first hotkey press would add a
    /// noticeable stall right when the popup should feel instant. Touching
    /// them here, on a background queue, warms that one-time cost before
    /// the user ever presses the hotkey.
    private func warmDatasetCachesInBackground() {
        DispatchQueue.global(qos: .utility).async {
            _ = SynonymStore.synonyms(for: "warmup", partOfSpeech: nil)
            _ = AntonymStore.antonyms(for: "warmup", partOfSpeech: nil)
            _ = RhymeStore.rhymes(for: "warmup")
            WordList.warmUp()
            _ = SystemDictionaries.thesaurus
        }
    }

    private func handleHotkey() {
        guard AXIsProcessTrusted() else {
            promptForAccessibilityPermission()
            return
        }
        // @MainActor: TextCapture's internal polling can resume on a
        // background thread after its `await`s, but AppKit (NSPanel, used
        // by popupController.show) must only ever be touched from the main
        // thread — without this, that call can crash.
        Task { @MainActor in
            guard let word = await TextCapture.captureSelectedText(), !word.isEmpty else { return }
            let entry = DictionaryLookup.lookup(word)
            let location = NSEvent.mouseLocation
            popupController.show(entry: entry, near: location)
        }
    }

    /// Without this, a missing/revoked Accessibility grant makes every
    /// hotkey press a silent no-op — the single most likely first-run
    /// failure, with no feedback at all.
    private func promptForAccessibilityPermission() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Needed"
        alert.informativeText = "WordPop needs Accessibility access to read your selected text. Grant it in System Settings > Privacy & Security > Accessibility, then try again."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func showPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(
                onLookupShortcutChanged: { [weak self] shortcut in
                    self?.hotkeyManager.update(shortcut: shortcut) ?? false
                },
                onQuickSearchShortcutChanged: { [weak self] shortcut in
                    self?.quickSearchHotkeyManager.update(shortcut: shortcut) ?? false
                }
            )
        }
        preferencesWindowController?.show()
    }
}
