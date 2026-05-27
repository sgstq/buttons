import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let engine: TriggerEngine
    private let permissions: PermissionsCoordinator
    private let onShowPreferences: () -> Void
    private let statusItem: NSStatusItem

    init(
        engine: TriggerEngine,
        permissions: PermissionsCoordinator,
        onShowPreferences: @escaping () -> Void
    ) {
        self.engine = engine
        self.permissions = permissions
        self.onShowPreferences = onShowPreferences
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "command.square",
                accessibilityDescription: "Buttons"
            )
            button.image?.isTemplate = true
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let pause = NSMenuItem(
            title: engine.isPaused ? "Resume Triggers" : "Pause Triggers",
            action: #selector(togglePause),
            keyEquivalent: ""
        )
        pause.target = self
        menu.addItem(pause)

        if !permissions.accessibilityGranted() {
            menu.addItem(.separator())
            let warn = NSMenuItem(
                title: "⚠︎ Accessibility access required",
                action: #selector(openAccessibility),
                keyEquivalent: ""
            )
            warn.target = self
            menu.addItem(warn)
        }

        menu.addItem(.separator())

        let prefs = NSMenuItem(
            title: "Preferences…",
            action: #selector(showPreferences),
            keyEquivalent: ","
        )
        prefs.target = self
        menu.addItem(prefs)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit Buttons",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func togglePause() {
        engine.setPaused(!engine.isPaused)
    }

    @objc private func openAccessibility() {
        permissions.openAccessibilitySettings()
    }

    @objc private func showPreferences() {
        onShowPreferences()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
