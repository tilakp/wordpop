import AppKit

/// A minimal Spotlight-style panel: borderless, non-activating, closes on
/// Escape. Unlike PopupPanel, Space is just a normal character here (typed
/// into the search field), not a "speak this word" shortcut.
final class QuickSearchPanel: NSPanel {
    var onEscape: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// WordPop has no Edit menu (it is a menu bar app), so nothing routes
    /// ⌘V, ⌘C, ⌘X, ⌘A and ⌘Z to the search field. Without this, pasting a
    /// word fails, and so do text-replacement tools (Typinator, Raycast)
    /// that correct a typo by deleting it and pasting the fix.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags == .command || flags == [.command, .shift] else { return super.performKeyEquivalent(with: event) }
        let action: Selector?
        switch (event.charactersIgnoringModifiers?.lowercased(), flags.contains(.shift)) {
        case ("v", false): action = #selector(NSText.paste(_:))
        case ("c", false): action = #selector(NSText.copy(_:))
        case ("x", false): action = #selector(NSText.cut(_:))
        case ("a", false): action = #selector(NSText.selectAll(_:))
        case ("z", false): action = Selector(("undo:"))
        case ("z", true): action = Selector(("redo:"))
        default: action = nil
        }
        if let action, NSApp.sendAction(action, to: nil, from: self) { return true }
        return super.performKeyEquivalent(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}
