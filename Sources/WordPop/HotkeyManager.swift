import AppKit
import Carbon.HIToolbox

/// Registers a system-wide hotkey that fires even when this app is not
/// frontmost. Uses an NSEvent global monitor rather than Carbon's
/// RegisterEventHotKey/InstallEventHandler: extensive on-device testing
/// found that Carbon's hotkey callback silently never fires on this macOS
/// version (RegisterEventHotKey succeeds, GetEventParameter runs, but
/// InstallEventHandler's callback is never invoked) even though the exact
/// same keyDown is reliably delivered to an NSEvent global monitor in the
/// same process. Carbon Event Manager is long-deprecated; NSEvent's global
/// monitor is the modern, reliable mechanism for this.
final class HotkeyManager {
    private let onPress: () -> Void
    private var monitor: Any?
    private var shortcut: HotkeyShortcut?

    init(onPress: @escaping () -> Void) {
        self.onPress = onPress
    }

    @discardableResult
    func register(shortcut: HotkeyShortcut) -> Bool {
        self.shortcut = shortcut
        installMonitorIfNeeded()
        return true
    }

    @discardableResult
    func update(shortcut: HotkeyShortcut) -> Bool {
        self.shortcut = shortcut
        installMonitorIfNeeded()
        return true
    }

    private func installMonitorIfNeeded() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
        }
    }

    private func handle(_ event: NSEvent) {
        guard let shortcut else { return }
        guard event.keyCode == UInt16(shortcut.keyCode) else { return }
        let pressed = event.modifierFlags.intersection([.control, .option, .shift, .command])
        guard pressed == Self.modifierFlags(fromCarbon: shortcut.carbonModifiers) else { return }
        onPress()
    }

    private static func modifierFlags(fromCarbon carbon: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbon & UInt32(controlKey) != 0 { flags.insert(.control) }
        if carbon & UInt32(optionKey) != 0 { flags.insert(.option) }
        if carbon & UInt32(cmdKey) != 0 { flags.insert(.command) }
        if carbon & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        return flags
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
