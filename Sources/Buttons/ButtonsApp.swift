import SwiftUI

struct ButtonsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        // SwiftUI requires at least one Scene. The preferences window is owned by AppKit
        // (see PreferencesWindowController) because Settings/Window scenes behave poorly
        // in LSUIElement (menu bar–only) apps. This Settings scene is a no-op placeholder.
        Settings { EmptyView() }
    }
}
