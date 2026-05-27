import AppKit

extension TriggerInput {
    var summary: String {
        switch self {
        case .hotkey(let h): return shortcutString(h)
        case .trackpad(let g): return "\(g.fingerCount)-finger \(g.kind.label)"
        }
    }
}

extension Action {
    var summary: String {
        switch self {
        case .sendKeystroke(let kc, let m):
            return shortcutString(Hotkey(keyCode: kc, modifiers: m))
        case .sendText(let s):
            let preview = s.prefix(24)
            return "Type \"\(preview)\(s.count > 24 ? "…" : "")\""
        case .sendMouseClick(let b):
            return "\(b.rawValue.capitalized) click"
        case .launchApp(let bid):
            return "Launch \(bid)"
        case .openURL(let url):
            return "Open \(url.absoluteString)"
        case .sequence(let actions):
            return actions.map(\.summary).joined(separator: " → ")
        case .delay(let s):
            return String(format: "Wait %.2gs", s)
        }
    }
}

extension Scope {
    var summary: String {
        switch self {
        case .global: return "Global"
        case .app(let bid): return bid
        }
    }
}

extension TrackpadGesture.Kind {
    var label: String {
        switch self {
        case .tap: return "tap"
        case .swipeUp: return "swipe up"
        case .swipeDown: return "swipe down"
        case .swipeLeft: return "swipe left"
        case .swipeRight: return "swipe right"
        }
    }
}

func shortcutString(_ h: Hotkey) -> String {
    var s = ""
    let mods = NSEvent.ModifierFlags(rawValue: UInt(h.modifiers))
    if mods.contains(.control) { s += "⌃" }
    if mods.contains(.option) { s += "⌥" }
    if mods.contains(.shift) { s += "⇧" }
    if mods.contains(.command) { s += "⌘" }
    s += keyName(for: h.keyCode)
    return s
}

func keyName(for keyCode: UInt32) -> String {
    let map: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C",
        9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
        26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[",
        34: "I", 35: "P", 36: "↩", 37: "L", 38: "J", 39: "'", 40: "K", 41: ";",
        42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        48: "⇥", 49: "Space", 50: "`", 51: "⌫", 53: "⎋",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
        109: "F10", 111: "F12", 118: "F4", 120: "F2", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]
    return map[keyCode] ?? "Key \(keyCode)"
}
