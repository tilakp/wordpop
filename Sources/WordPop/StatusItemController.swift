import AppKit

/// The menu bar icon that gives this accessory (Dock-less) app a way to reach
/// Preferences and Quit.
final class StatusItemController: NSObject {
    private var statusItem: NSStatusItem?
    private let onPreferences: () -> Void
    private let onQuit: () -> Void

    init(onPreferences: @escaping () -> Void, onQuit: @escaping () -> Void) {
        self.onPreferences = onPreferences
        self.onQuit = onQuit
        super.init()
        setUp()
    }

    private func setUp() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "character.book.closed.fill", accessibilityDescription: "WordPop")

        let menu = NSMenu()
        let preferencesItem = NSMenuItem(title: "Preferences\u{2026}", action: #selector(preferencesClicked), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit WordPop", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    @objc private func preferencesClicked() { onPreferences() }
    @objc private func quitClicked() { onQuit() }
}
