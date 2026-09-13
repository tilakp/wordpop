import AppKit

/// A minimal Spotlight-style panel: borderless, non-activating, closes on
/// Escape. Unlike PopupPanel, Space is just a normal character here (typed
/// into the search field), not a "speak this word" shortcut.
final class QuickSearchPanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}
