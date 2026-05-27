import Foundation

struct Trigger: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var enabled: Bool
    var scope: Scope
    var input: TriggerInput
    var action: Action

    init(
        id: UUID = UUID(),
        name: String = "",
        enabled: Bool = true,
        scope: Scope = .global,
        input: TriggerInput,
        action: Action
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.scope = scope
        self.input = input
        self.action = action
    }
}

enum Scope: Codable, Equatable, Hashable {
    case global
    case app(bundleID: String)

    func matches(frontmostBundleID: String?) -> Bool {
        switch self {
        case .global: return true
        case .app(let bid): return bid == frontmostBundleID
        }
    }
}

enum TriggerInput: Codable, Equatable, Hashable {
    case hotkey(Hotkey)
    case trackpad(TrackpadGesture)
}

struct Hotkey: Codable, Equatable, Hashable {
    /// macOS virtual key code (kVK_*).
    var keyCode: UInt32
    /// Bit flags matching NSEvent.ModifierFlags rawValue (Cocoa, not Carbon).
    var modifiers: UInt32
}

struct TrackpadGesture: Codable, Equatable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        case tap
        case swipeUp, swipeDown, swipeLeft, swipeRight
    }
    var kind: Kind
    var fingerCount: Int
}

indirect enum Action: Codable, Equatable, Hashable {
    case sendKeystroke(keyCode: UInt32, modifiers: UInt32)
    case sendText(String)
    case sendMouseClick(button: MouseButton)
    case launchApp(bundleID: String)
    case openURL(URL)
    /// Run actions in order. Embedded `.delay` steps pause before the next action.
    case sequence([Action])
    /// Standalone: no-op. Inside a `.sequence`, pauses execution for this many seconds.
    case delay(seconds: Double)
}

enum MouseButton: String, Codable, CaseIterable {
    case left, middle, right
}
