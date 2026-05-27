import AppKit
import CoreGraphics

@MainActor
final class ActionDispatcher {
    private let source = CGEventSource(stateID: .hidSystemState)

    func dispatch(_ action: Action) {
        switch action {
        case .sendKeystroke(let keyCode, let modifiers):
            sendKey(UInt16(keyCode), flags: cgFlags(from: modifiers))
        case .sendText(let text):
            sendText(text)
        case .sendMouseClick(let button):
            sendClick(button: button)
        case .launchApp(let bundleID):
            launchApp(bundleID: bundleID)
        case .openURL(let url):
            NSWorkspace.shared.open(url)
        case .sequence(let actions):
            runSequence(actions, index: 0)
        case .delay:
            // Standalone delay is a no-op; it only matters inside a sequence.
            break
        }
    }

    private func runSequence(_ actions: [Action], index: Int) {
        guard index < actions.count else { return }
        let next = actions[index]
        if case .delay(let secs) = next {
            DispatchQueue.main.asyncAfter(deadline: .now() + secs) { [weak self] in
                self?.runSequence(actions, index: index + 1)
            }
        } else {
            dispatch(next)
            runSequence(actions, index: index + 1)
        }
    }

    private func sendKey(_ keyCode: UInt16, flags: CGEventFlags) {
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func sendText(_ text: String) {
        let utf16 = Array(text.utf16)
        guard !utf16.isEmpty else { return }
        // Posting the whole string in one event works for most apps.
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else { return }
        utf16.withUnsafeBufferPointer { buf in
            if let base = buf.baseAddress {
                down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: base)
                up.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: base)
            }
        }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func sendClick(button: MouseButton) {
        let nsLoc = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(nsLoc, $0.frame, false) }) ?? NSScreen.main
        let cgLoc: CGPoint
        if let screen = screen {
            // Convert Cocoa (origin lower-left of primary screen) to CG (origin upper-left)
            let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
            cgLoc = CGPoint(x: nsLoc.x, y: primaryHeight - nsLoc.y)
        } else {
            cgLoc = .zero
        }

        let cgButton: CGMouseButton
        let downType: CGEventType
        let upType: CGEventType
        switch button {
        case .left:
            cgButton = .left; downType = .leftMouseDown; upType = .leftMouseUp
        case .middle:
            cgButton = .center; downType = .otherMouseDown; upType = .otherMouseUp
        case .right:
            cgButton = .right; downType = .rightMouseDown; upType = .rightMouseUp
        }

        let downEv = CGEvent(mouseEventSource: source, mouseType: downType, mouseCursorPosition: cgLoc, mouseButton: cgButton)
        let upEv = CGEvent(mouseEventSource: source, mouseType: upType, mouseCursorPosition: cgLoc, mouseButton: cgButton)
        downEv?.post(tap: .cghidEventTap)
        upEv?.post(tap: .cghidEventTap)
    }

    private func launchApp(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
    }

    private func cgFlags(from cocoaRaw: UInt32) -> CGEventFlags {
        var f: CGEventFlags = []
        let cocoa = NSEvent.ModifierFlags(rawValue: UInt(cocoaRaw))
        if cocoa.contains(.command)  { f.insert(.maskCommand) }
        if cocoa.contains(.shift)    { f.insert(.maskShift) }
        if cocoa.contains(.option)   { f.insert(.maskAlternate) }
        if cocoa.contains(.control)  { f.insert(.maskControl) }
        if cocoa.contains(.function) { f.insert(.maskSecondaryFn) }
        return f
    }
}
