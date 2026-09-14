import AppKit

/// A borderless, non-activating floating panel: it can become key (to receive
/// Escape and clicks) without stealing focus/activation from whatever app the
/// user was in, and without showing a Dock icon or menu bar switch.
final class PopupPanel: NSPanel {
    var onEscape: (() -> Void)?
    /// Return true to consume the event; otherwise it falls through to the
    /// content (e.g. arrow keys scrolling the definitions).
    var onKey: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // kVK_Escape
            onEscape?()
            return
        }
        if onKey?(event) == true {
            return
        }
        super.keyDown(with: event)
    }

    /// Command shortcuts (⌘C, ⌘[) never reach keyDown on a panel without a
    /// menu bar to route them, so they are intercepted here.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), onKey?(event) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}
