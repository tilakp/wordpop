import AppKit

/// Captures the currently selected text in whatever app is frontmost by
/// simulating Cmd+C and reading the clipboard, then restores the clipboard
/// to what it held before. Requires Accessibility permission to post events.
///
/// This is the same clipboard-simulation technique used by PopClip,
/// Alfred's clipboard actions, and similar tools — it has an inherent, hard
/// -to-close race: if the frontmost app is slow to write its own copy (a
/// heavily loaded Electron app, a remote session), our restore can land
/// before that copy does, and it ends up overwriting the user's clipboard
/// with our restored (stale) content. The brief extra wait below narrows
/// that window but can't eliminate it without a fundamentally different,
/// OS-level way to read a selection.
enum TextCapture {
    static func captureSelectedText() async -> String? {
        let pasteboard = NSPasteboard.general
        // Only the plain-text representation is saved/restored (not a full
        // multi-type item copy) — cheap, and covers the case that matters;
        // a non-text item (e.g. an image) already on the clipboard is left
        // alone below rather than destroyed by an incomplete restore.
        let savedString = pasteboard.string(forType: .string)
        let priorChangeCount = pasteboard.changeCount

        simulateCommandC()

        let didChange = await waitForPasteboardChange(from: priorChangeCount, timeout: 0.3)
        let result = didChange ? pasteboard.string(forType: .string) : nil
        let changeCountAfterRead = pasteboard.changeCount

        // Give a slow app's own copy a brief extra moment to land before
        // restoring, so we don't clobber it (see doc comment above).
        try? await Task.sleep(nanoseconds: 60_000_000)
        if pasteboard.changeCount == changeCountAfterRead, let savedString {
            pasteboard.clearContents()
            pasteboard.setString(savedString, forType: .string)
        }

        return result?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func simulateCommandC() {
        let source = CGEventSource(stateID: .hidSystemState)
        let cKeyCode: CGKeyCode = 0x08 // 'C'

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private static func waitForPasteboardChange(from priorChangeCount: Int, timeout: TimeInterval) async -> Bool {
        let pasteboard = NSPasteboard.general
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if pasteboard.changeCount != priorChangeCount {
                return true
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return false
    }
}
