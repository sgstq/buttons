import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    private let store: TriggerStore
    private let engine: TriggerEngine
    private let settings: AppSettings
    private let permissionsBox: PermissionsCoordinatorBox

    init(
        store: TriggerStore,
        engine: TriggerEngine,
        settings: AppSettings,
        permissionsBox: PermissionsCoordinatorBox
    ) {
        self.store = store
        self.engine = engine
        self.settings = settings
        self.permissionsBox = permissionsBox

        let root = PreferencesScene()
            .environmentObject(store)
            .environmentObject(engine)
            .environmentObject(settings)
            .environmentObject(permissionsBox)

        let hosting = NSHostingController(rootView: root)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Buttons"
        window.contentViewController = hosting
        window.setContentSize(NSSize(width: 900, height: 560))
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 780, height: 460)

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        if window?.isVisible != true {
            window?.center()
        }
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // No-op — we keep the window instance alive (isReleasedWhenClosed = false)
        // so reopening from the menu bar is instant.
    }
}
