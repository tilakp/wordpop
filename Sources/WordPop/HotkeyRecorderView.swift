import AppKit
import SwiftUI
import Carbon.HIToolbox

/// A click-to-record control for capturing a global keyboard shortcut,
/// similar to the recorder in System Settings > Keyboard Shortcuts.
final class KeyRecorderNSView: NSView {
    var shortcut: HotkeyShortcut = HotkeySettings.current { didSet { needsDisplay = true } }
    var onChange: ((HotkeyShortcut) -> Void)?
    private var isRecording = false { didSet { needsDisplay = true } }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        _ = becomeFirstResponder()
        isRecording = true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        if event.keyCode == UInt16(kVK_Escape) {
            isRecording = false
            return
        }
        guard let newShortcut = HotkeyShortcut(recordingEvent: event) else {
            NSSound.beep()
            return
        }
        shortcut = newShortcut
        isRecording = false
        onChange?(newShortcut)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.15) : NSColor.controlBackgroundColor).setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = 1
        path.stroke()

        let text = isRecording ? "Type shortcut\u{2026}" : shortcut.displayString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: isRecording ? NSColor.controlAccentColor : NSColor.labelColor
        ]
        let size = text.size(withAttributes: attributes)
        let point = NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2)
        text.draw(at: point, withAttributes: attributes)
    }
}

struct HotkeyRecorder: NSViewRepresentable {
    @Binding var shortcut: HotkeyShortcut

    func makeNSView(context: Context) -> KeyRecorderNSView {
        let view = KeyRecorderNSView()
        view.shortcut = shortcut
        view.onChange = { newShortcut in
            shortcut = newShortcut
        }
        return view
    }

    func updateNSView(_ nsView: KeyRecorderNSView, context: Context) {
        nsView.shortcut = shortcut
    }
}
