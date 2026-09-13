import ServiceManagement

/// Registers/unregisters WordPop as a login item using the modern
/// ServiceManagement API. The registration itself is the source of truth
/// (no separate UserDefaults flag needed) — `isEnabled` just reflects
/// whatever SMAppService currently reports.
enum LoginItemManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Registration can fail if the app isn't running from a stable,
            // installed location (e.g. launched straight out of the build
            // directory during development) — nothing to recover from here
            // beyond leaving the toggle at whatever SMAppService reports.
        }
    }
}
