import AppKit
import Carbon.HIToolbox

/// Registers a system-wide hotkey with Carbon's RegisterEventHotKey. Unlike
/// an NSEvent global monitor, a registered hotkey is consumed (⌘\ no longer
/// also reaches the frontmost app), fires while one of WordPop's own panels
/// is key, and fails to register when another app already owns the
/// combination. The handler is installed on the event dispatcher target:
/// on the application target its callback never runs in an app started
/// with NSApplication.run.
final class HotkeyManager {
    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var eventHandler: EventHandlerRef?
    private static let signature = OSType(0x5750_4F50) // 'WPOP'
    private static let all = NSHashTable<HotkeyManager>.weakObjects()

    /// True while a shortcut recorder in Settings records. A registered
    /// hotkey takes its key press before any window sees it, so without
    /// this, pressing the lookup shortcut in the Quick Search recorder ran
    /// a lookup and the "already the Lookup shortcut" message never showed.
    static var isSuspended = false {
        didSet {
            guard isSuspended != oldValue else { return }
            for manager in all.allObjects {
                if isSuspended {
                    if let hotKey = manager.hotKey { UnregisterEventHotKey(hotKey) }
                    manager.hotKey = nil
                } else if let shortcut = manager.shortcut {
                    _ = manager.install(shortcut)
                }
            }
        }
    }

    private let id: UInt32
    private let onPress: () -> Void
    private var hotKey: EventHotKeyRef?
    private(set) var shortcut: HotkeyShortcut?

    init(onPress: @escaping () -> Void) {
        self.onPress = onPress
        id = Self.nextID
        Self.nextID += 1
        Self.installEventHandlerIfNeeded()
        Self.all.add(self)
    }

    /// Returns false when the shortcut could not be registered, most
    /// likely because another app has it; the previous shortcut then
    /// stays active.
    @discardableResult
    func register(shortcut newShortcut: HotkeyShortcut) -> Bool {
        let previous = shortcut
        unregister()
        if install(newShortcut) { return true }
        if let previous { _ = install(previous) }
        return false
    }

    private func install(_ newShortcut: HotkeyShortcut) -> Bool {
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            newShortcut.keyCode, newShortcut.carbonModifiers, EventHotKeyID(signature: Self.signature, id: id),
            // Exclusive: fail, rather than silently share the key, when
            // another app already registered it.
            GetEventDispatcherTarget(), UInt32(kEventHotKeyExclusive), &ref
        )
        guard status == noErr, let ref else { return false }
        hotKey = ref
        shortcut = newShortcut
        Self.actions[id] = onPress
        return true
    }

    private func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        shortcut = nil
        Self.actions[id] = nil
    }

    private static func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
            )
            guard status == noErr, hotKeyID.signature == HotkeyManager.signature else { return OSStatus(eventNotHandledErr) }
            DispatchQueue.main.async { HotkeyManager.actions[hotKeyID.id]?() }
            return noErr
        }, 1, &pressed, nil, &eventHandler)
    }

    deinit {
        unregister()
    }
}
