import SwiftUI

/// A labeled hotkey recorder with a Reset button and inline error message,
/// used for both the lookup and quick-search shortcuts in Preferences.
struct ShortcutSettingRow: View {
    let title: String
    let subtitle: String
    let defaultShortcut: HotkeyShortcut
    /// Attempts to apply a new shortcut (re-registering the global hotkey);
    /// returns false if that failed (most likely already claimed by another
    /// app), in which case the row reverts to the previous value.
    let onChange: (HotkeyShortcut) -> Bool

    @State private var shortcut: HotkeyShortcut
    @State private var errorMessage: String?
    /// Suppresses `onChange` from re-processing our own programmatic revert
    /// on failure (which would otherwise immediately re-apply the reverted
    /// value and clear the error message we just set).
    @State private var isReverting = false

    init(title: String, subtitle: String, current: HotkeyShortcut, defaultShortcut: HotkeyShortcut, onChange: @escaping (HotkeyShortcut) -> Bool) {
        self.title = title
        self.subtitle = subtitle
        self.defaultShortcut = defaultShortcut
        self.onChange = onChange
        _shortcut = State(initialValue: current)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            HStack(spacing: 10) {
                HotkeyRecorder(shortcut: $shortcut)
                    .frame(width: 140, height: 26)
                    .onChange(of: shortcut) { oldValue, newValue in
                        guard !isReverting else {
                            isReverting = false
                            return
                        }
                        apply(newValue, revertTo: oldValue)
                    }

                Button("Reset") {
                    let previous = shortcut
                    shortcut = defaultShortcut
                    apply(defaultShortcut, revertTo: previous)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func apply(_ newValue: HotkeyShortcut, revertTo previous: HotkeyShortcut) {
        if onChange(newValue) {
            errorMessage = nil
        } else {
            errorMessage = "Couldn't use \(newValue.displayString) — it may already be in use by another app."
            isReverting = true
            shortcut = previous
        }
    }
}
