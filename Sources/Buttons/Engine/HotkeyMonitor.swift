import AppKit
import Carbon.HIToolbox

final class HotkeyMonitor {
    private struct Registration {
        let ref: EventHotKeyRef
        let id: UInt32
    }

    private var registrations: [Registration] = []
    private var nextID: UInt32 = 1
    private var handlerInstalled = false
    private var handlerRef: EventHandlerRef?

    /// Global lookup from hotkey-id to handler closure. Static because the Carbon callback is a C function.
    fileprivate static var handlers: [UInt32: () -> Void] = [:]

    @discardableResult
    func register(hotkey: Hotkey, handler: @escaping () -> Void) -> Bool {
        installHandlerIfNeeded()
        let id = nextID
        nextID &+= 1
        let signature: OSType = 0x42_54_4E_53 // 'BTNS'
        let hkID = EventHotKeyID(signature: signature, id: id)
        var ref: EventHotKeyRef?
        let mods = carbonModifiers(from: hotkey.modifiers)
        let status = RegisterEventHotKey(hotkey.keyCode, mods, hkID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref = ref else {
            NSLog("Buttons: RegisterEventHotKey failed for keyCode=\(hotkey.keyCode) mods=\(mods) status=\(status)")
            return false
        }
        registrations.append(Registration(ref: ref, id: id))
        Self.handlers[id] = handler
        return true
    }

    func unregisterAll() {
        for reg in registrations {
            UnregisterEventHotKey(reg.ref)
            Self.handlers.removeValue(forKey: reg.id)
        }
        registrations.removeAll()
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), { _, eventOpt, _ in
            guard let event = eventOpt else { return noErr }
            var hkID = EventHotKeyID()
            let err = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hkID
            )
            if err == noErr, let handler = HotkeyMonitor.handlers[hkID.id] {
                DispatchQueue.main.async { handler() }
            }
            return noErr
        }, 1, &spec, nil, &handlerRef)
        handlerInstalled = true
    }

    private func carbonModifiers(from cocoa: UInt32) -> UInt32 {
        var c: UInt32 = 0
        let flags = NSEvent.ModifierFlags(rawValue: UInt(cocoa))
        if flags.contains(.command) { c |= UInt32(cmdKey) }
        if flags.contains(.shift)   { c |= UInt32(shiftKey) }
        if flags.contains(.option)  { c |= UInt32(optionKey) }
        if flags.contains(.control) { c |= UInt32(controlKey) }
        return c
    }
}
