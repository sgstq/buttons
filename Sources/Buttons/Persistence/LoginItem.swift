import Foundation
import ServiceManagement

/// Manages whether Buttons launches automatically at login, via `SMAppService.mainApp`.
///
/// `SMAppService` is the source of truth: macOS persists the registration and the user can also
/// toggle it from System Settings → General → Login Items, so there is no UserDefaults mirror
/// here. Registration only succeeds for a bundled, signed app (i.e. Buttons.app); from a bare
/// `swift run` binary the calls throw, which we log and surface via the returned state.
enum LoginItem {
    /// Whether the app is currently registered as an enabled login item.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers or unregisters the app as a login item, then returns the resulting state.
    /// A return value that differs from `enabled` means the change could not be applied
    /// (e.g. the binary isn't bundled, or the user must approve it in System Settings).
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled { try service.register() }
            } else {
                if service.status == .enabled { try service.unregister() }
            }
        } catch {
            NSLog("Buttons: failed to \(enabled ? "register" : "unregister") login item: \(error)")
        }
        return service.status == .enabled
    }
}
