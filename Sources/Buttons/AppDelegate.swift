import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store: TriggerStore
    let settings: AppSettings
    let permissions: PermissionsCoordinator
    let permissionsBox: PermissionsCoordinatorBox
    let context: ContextProvider
    let dispatcher: ActionDispatcher
    let engine: TriggerEngine

    private var menuBar: MenuBarController?
    private(set) var preferencesController: PreferencesWindowController?
    private var cancellables: Set<AnyCancellable> = []

    override init() {
        let store = TriggerStore()
        let settings = AppSettings()
        let permissions = PermissionsCoordinator()
        let context = ContextProvider()
        let dispatcher = ActionDispatcher()
        let engine = TriggerEngine(store: store, context: context, dispatcher: dispatcher)

        self.store = store
        self.settings = settings
        self.permissions = permissions
        self.permissionsBox = PermissionsCoordinatorBox(coordinator: permissions)
        self.context = context
        self.dispatcher = dispatcher
        self.engine = engine
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        store.load()
        engine.start()

        let prefs = PreferencesWindowController(
            store: store,
            engine: engine,
            settings: settings,
            permissionsBox: permissionsBox
        )
        preferencesController = prefs

        let menuBar = MenuBarController(
            engine: engine,
            permissions: permissions,
            onShowPreferences: { [weak self] in self?.showPreferences() }
        )
        menuBar.setVisible(settings.menuBarVisible)
        self.menuBar = menuBar

        settings.$menuBarVisible
            .dropFirst()
            .sink { [weak self] visible in
                self?.menuBar?.setVisible(visible)
            }
            .store(in: &cancellables)

        // Trigger the one-time system Accessibility prompt so the user knows it's needed.
        if !permissions.accessibilityGranted() {
            permissions.requestAccessibility()
        }

        // On a clean first launch (no triggers yet) open the preferences window
        // so the user has something to look at.
        if store.triggers.isEmpty {
            showPreferences()
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.permissionsBox.refresh()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showPreferences()
        return false
    }

    func showPreferences() {
        preferencesController?.show()
    }
}
