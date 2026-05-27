import AppKit
import ApplicationServices

final class PermissionsCoordinator {
    func accessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user to grant Accessibility access. Triggers the system dialog only on first call;
    /// subsequent calls are silent until the user resets via tccutil.
    @discardableResult
    func requestAccessibility() -> Bool {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let opts: CFDictionary = [key: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
