import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    private static let menuBarVisibleKey = "buttons.menuBarVisible"

    @Published var menuBarVisible: Bool {
        didSet {
            UserDefaults.standard.set(menuBarVisible, forKey: Self.menuBarVisibleKey)
        }
    }

    /// Whether Buttons launches automatically at login. Backed by `SMAppService` (see `LoginItem`),
    /// not UserDefaults: macOS owns this registration and the user can also change it from System
    /// Settings, so we mirror the system state and write through to it on change.
    @Published var launchAtLogin: Bool {
        didSet {
            guard !isSyncingLaunchAtLogin, launchAtLogin != oldValue else { return }
            let actual = LoginItem.setEnabled(launchAtLogin)
            if actual != launchAtLogin {
                // The change couldn't be applied — snap the toggle back to reality without recursing.
                isSyncingLaunchAtLogin = true
                launchAtLogin = actual
                isSyncingLaunchAtLogin = false
            }
        }
    }

    /// Guards the `launchAtLogin` setter so that programmatic re-syncs don't write back to the system.
    private var isSyncingLaunchAtLogin = false

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Self.menuBarVisibleKey: true])
        self.menuBarVisible = defaults.bool(forKey: Self.menuBarVisibleKey)
        self.launchAtLogin = LoginItem.isEnabled
    }

    /// Re-reads the login-item registration so the toggle reflects changes made elsewhere (e.g. in
    /// System Settings while the app was inactive). Only publishes when the value actually changed.
    func refreshLaunchAtLogin() {
        let enabled = LoginItem.isEnabled
        guard enabled != launchAtLogin else { return }
        isSyncingLaunchAtLogin = true
        launchAtLogin = enabled
        isSyncingLaunchAtLogin = false
    }
}
