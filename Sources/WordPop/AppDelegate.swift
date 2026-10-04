import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager!
    private var quickSearchHotkeyManager: HotkeyManager!
    private var popupController: PopupController!
    private var quickSearchController: QuickSearchController!
    private var statusItemController: StatusItemController!
    private var preferencesWindowController: PreferencesWindowController?

    /// The controllers exist before launch finishes: a wordpop:// URL that
    /// launches the app is delivered before applicationDidFinishLaunching.
    func applicationWillFinishLaunching(_ notification: Notification) {
        popupController = PopupController()
        quickSearchController = QuickSearchController { [weak self] word in
            let entry = DictionaryLookup.lookup(word)
            self?.popupController.show(entry: entry, near: NSEvent.mouseLocation)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        requestAccessibilityPermissionIfNeeded()
        warmDatasetCachesInBackground()

        hotkeyManager = HotkeyManager { [weak self] in
            self?.handleHotkey()
        }
        hotkeyManager.register(shortcut: HotkeySettings.current)

        quickSearchHotkeyManager = HotkeyManager { [weak self] in
            self?.quickSearchController.show()
        }
        quickSearchHotkeyManager.register(shortcut: HotkeySettings.quickSearch)

        NSApp.servicesProvider = self
        NSUpdateDynamicServices()

        statusItemController = StatusItemController(
            onPreferences: { [weak self] in self?.showPreferences() },
            onQuit: { NSApp.terminate(nil) }
        )
    }

    private func requestAccessibilityPermissionIfNeeded() {
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Opening the bundled database and enumerating the system dictionaries
    /// each take a moment; doing it on a background queue at launch keeps
    /// the first hotkey press instant.
    private func warmDatasetCachesInBackground() {
        DispatchQueue.global(qos: .utility).async {
            Database.warmUp()
            _ = SystemDictionaries.thesaurus
            _ = SystemDictionaries.english
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
            guard let selection = await TextCapture.captureSelection() else { return }
            if TextStats.isPassage(selection.trimmed) {
                popupController.show(passage: selection.trimmed, near: NSEvent.mouseLocation)
                return
            }
            let entry = DictionaryLookup.lookup(selection.trimmed)
            let location = NSEvent.mouseLocation
            popupController.show(entry: entry, near: location, replacing: selection)
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
                    self?.apply(shortcut, to: self?.hotkeyManager, other: self?.quickSearchHotkeyManager, otherName: "Quick Search")
                },
                onQuickSearchShortcutChanged: { [weak self] shortcut in
                    self?.apply(shortcut, to: self?.quickSearchHotkeyManager, other: self?.hotkeyManager, otherName: "Lookup")
                }
            )
        }
        preferencesWindowController?.show()
    }

    /// `wordpop://lookup?word=serendipity` shows the popup for a word and
    /// `wordpop://search` opens Quick Search, for Shortcuts, launchers and
    /// scripts.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "wordpop" {
            switch url.host {
            case "lookup":
                let word = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first { $0.name == "word" }?.value?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !word.isEmpty { showLookup(word) }
            case "search":
                quickSearchController.show()
            default:
                break
            }
        }
    }

    /// The "Look Up in WordPop" item in the Services menu.
    @objc func lookUp(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return }
        showLookup(text)
    }

    private func showLookup(_ text: String) {
        popupController.show(entry: DictionaryLookup.lookup(text), near: NSEvent.mouseLocation)
    }

    /// Returns an error message, or nil when the shortcut is now active.
    private func apply(_ shortcut: HotkeyShortcut, to manager: HotkeyManager?, other: HotkeyManager?, otherName: String) -> String? {
        if other?.shortcut == shortcut {
            return "\(shortcut.displayString) is already the \(otherName) shortcut."
        }
        guard manager?.register(shortcut: shortcut) == true else {
            return "Couldn\u{2019}t use \(shortcut.displayString). Another app may already use it."
        }
        return nil
    }
}
