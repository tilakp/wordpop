import Carbon.HIToolbox
import AppKit

struct HotkeyShortcut: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var displayCharacter: String

    static let `default` = HotkeyShortcut(
        keyCode: UInt32(kVK_ANSI_D),
        carbonModifiers: UInt32(controlKey | optionKey | cmdKey),
        displayCharacter: "D"
    )

    static let defaultQuickSearch = HotkeyShortcut(
        keyCode: UInt32(kVK_ANSI_S),
        carbonModifiers: UInt32(controlKey | optionKey | cmdKey),
        displayCharacter: "S"
    )

    var displayString: String {
        var s = ""
        if carbonModifiers & UInt32(controlKey) != 0 { s += "\u{2303}" }
        if carbonModifiers & UInt32(optionKey) != 0 { s += "\u{2325}" }
        if carbonModifiers & UInt32(shiftKey) != 0 { s += "\u{21E7}" }
        if carbonModifiers & UInt32(cmdKey) != 0 { s += "\u{2318}" }
        s += displayCharacter
        return s
    }

    init(keyCode: UInt32, carbonModifiers: UInt32, displayCharacter: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.displayCharacter = displayCharacter
    }

    /// Builds a shortcut from a captured NSEvent. Fails if no modifier is held,
    /// to avoid accidentally binding a shortcut to a plain letter key.
    init?(recordingEvent event: NSEvent) {
        guard event.type == .keyDown else { return nil }
        var carbon: UInt32 = 0
        let flags = event.modifierFlags
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        guard carbon != 0 else { return nil }

        var displayCharacter = (event.charactersIgnoringModifiers ?? "").uppercased()
        if displayCharacter.isEmpty || displayCharacter == "\u{1B}" {
            displayCharacter = "?"
        }
        self.keyCode = UInt32(event.keyCode)
        self.carbonModifiers = carbon
        self.displayCharacter = displayCharacter
    }
}

enum HotkeySettings {
    private static let lookupKey = "WordPop.hotkeyShortcut"
    private static let quickSearchKey = "WordPop.quickSearchShortcut"

    static var current: HotkeyShortcut {
        get { load(lookupKey, default: .default) }
        set { save(newValue, lookupKey) }
    }

    static var quickSearch: HotkeyShortcut {
        get { load(quickSearchKey, default: .defaultQuickSearch) }
        set { save(newValue, quickSearchKey) }
    }

    private static func load(_ key: String, default defaultValue: HotkeyShortcut) -> HotkeyShortcut {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(HotkeyShortcut.self, from: data) else {
            return defaultValue
        }
        return decoded
    }

    private static func save(_ shortcut: HotkeyShortcut, _ key: String) {
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
