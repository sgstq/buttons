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

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Self.menuBarVisibleKey: true])
        self.menuBarVisible = defaults.bool(forKey: Self.menuBarVisibleKey)
    }
}
