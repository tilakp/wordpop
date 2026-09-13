import AppKit

/// A borderless, non-activating floating panel: it can become key (to receive
/// Escape and clicks) without stealing focus/activation from whatever app the
/// user was in, and without showing a Dock icon or menu bar switch.
final class PopupPanel: NSPanel {
    var onEscape: (() -> Void)?
    var onSpace: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // kVK_Escape
            onEscape?()
            return
        }
        if event.keyCode == 49 { // kVK_Space
            onSpace?()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }
}
