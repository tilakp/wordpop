import AppKit

/// Captures the currently selected text in whatever app is frontmost.
///
/// First choice is the Accessibility API: the focused element's
/// AXSelectedText, which native apps (Safari, Mail, Notes, Xcode, most
/// Chromium browsers) expose and which touches nothing. Apps that don't
/// (many Electron apps, terminals, remote desktops) fall back to simulating
/// Cmd+C and reading the clipboard, then restoring it. Both need
/// Accessibility permission.
///
/// The clipboard route is the same technique PopClip and Alfred use, and
/// has an inherent, hard-to-close race: if the frontmost app is slow to
/// write its own copy, our restore can land before that copy does and
/// overwrite the user's clipboard with stale content. The brief extra wait
/// below narrows that window but can't eliminate it.
enum TextCapture {
    static func captureSelectedText() async -> String? {
        if let selected = accessibilitySelectedText(), !selected.isEmpty {
            return selected
        }
        return await clipboardSelectedText()
    }

    private static func accessibilitySelectedText() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value) == .success else {
            return nil
        }
        return (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func clipboardSelectedText() async -> String? {
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
