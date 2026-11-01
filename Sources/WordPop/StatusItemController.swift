import AppKit

/// The menu bar icon that gives this accessory (Dock-less) app a way to reach
/// Preferences and Quit.
final class StatusItemController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let lookUpHintItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let quickSearchItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let onQuickSearch: () -> Void
    private let onPreferences: () -> Void
    private let onPractice: () -> Void
    private let onQuit: () -> Void

    init(onQuickSearch: @escaping () -> Void, onPreferences: @escaping () -> Void, onPractice: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onQuickSearch = onQuickSearch
        self.onPreferences = onPreferences
        self.onPractice = onPractice
        self.onQuit = onQuit
        super.init()
        setUp()
    }

    private func setUp() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "character.book.closed.fill", accessibilityDescription: "WordPop")

        let menu = NSMenu()
        menu.delegate = self
        // Filled in each time the menu opens, as the shortcuts can change.
        lookUpHintItem.isEnabled = false
        menu.addItem(lookUpHintItem)
        quickSearchItem.action = #selector(quickSearchClicked)
        quickSearchItem.target = self
        menu.addItem(quickSearchItem)
        menu.addItem(.separator())
        let preferencesItem = NSMenuItem(title: "Settings\u{2026}", action: #selector(preferencesClicked), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)
        let practiceItem = NSMenuItem(title: "Practice Starred Words\u{2026}", action: #selector(practiceClicked), keyEquivalent: "")
        practiceItem.target = self
        menu.addItem(practiceItem)
        let copyStarredItem = NSMenuItem(title: "Copy Starred Words", action: #selector(copyStarredClicked), keyEquivalent: "")
        copyStarredItem.target = self
        menu.addItem(copyStarredItem)
        let clearHistoryItem = NSMenuItem(title: "Clear History", action: #selector(clearHistoryClicked), keyEquivalent: "")
        clearHistoryItem.target = self
        menu.addItem(clearHistoryItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit WordPop", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    @objc private func quickSearchClicked() { onQuickSearch() }
    @objc private func preferencesClicked() { onPreferences() }
    @objc private func practiceClicked() { onPractice() }
    @objc private func copyStarredClicked() { StarredWords.shared.copyToClipboard() }
    /// Clears recent lookups and the counts of replaced words.
    @objc private func clearHistoryClicked() {
        LookupHistory.shared.clear()
        ReplacedWords.shared.clear()
    }
    @objc private func quitClicked() { onQuit() }

    /// The two shortcuts, as they are set now.
    func menuWillOpen(_ menu: NSMenu) {
        lookUpHintItem.title = "Look up: select text and press \(HotkeySettings.current.displayString)"
        quickSearchItem.title = "Quick Search (\(HotkeySettings.quickSearch.displayString))"
    }
}
