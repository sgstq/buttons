import Foundation
import SQLite3
import AppKit

/// Best-effort importer for BetterTouchTool's Core Data SQLite store.
///
/// BTT's schema is undocumented — this importer maps the cases we can recognize
/// (hotkey triggers, common trackpad gesture IDs) and reports the rest as skipped.
final class BTTImporter {
    struct ImportResult {
        var triggers: [Trigger]
        var skipped: [Skip]

        struct Skip: Identifiable {
            let id: Int32
            let gestureType: Int32
            let actionCode: Int32
            let reason: String
        }
    }

    enum ImportError: Error, LocalizedError {
        case noDatabaseFound
        case openFailed(String)
        case readFailed(String)

        var errorDescription: String? {
            switch self {
            case .noDatabaseFound:
                return "No BetterTouchTool database found. Expected files matching btt_data_store.version_* in ~/Library/Application Support/BetterTouchTool."
            case .openFailed(let s):
                return "Could not open BTT database: \(s)"
            case .readFailed(let s):
                return "Failed to read triggers: \(s)"
            }
        }
    }

    /// Reads and returns all triggers + skipped-row diagnostics.
    func read() throws -> ImportResult {
        let url = try latestDatabaseURL()
        return try readDatabase(at: url)
    }

    private func latestDatabaseURL() throws -> URL {
        let dir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/BetterTouchTool", isDirectory: true)
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        let candidates = files
            .filter { f in
                let name = f.lastPathComponent
                return name.hasPrefix("btt_data_store.version_")
                    && !name.hasSuffix("-shm")
                    && !name.hasSuffix("-wal")
                    && !name.hasSuffix(".version")
            }
        guard let latest = candidates.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }).first else {
            throw ImportError.noDatabaseFound
        }
        return latest
    }

    private func readDatabase(at url: URL) throws -> ImportResult {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            let msg = handle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(handle)
            throw ImportError.openFailed(msg)
        }
        defer { sqlite3_close(handle) }

        let sql = """
            SELECT Z_PK, ZGESTURETYPE, ZACTION,
                   ZSHORTCUT, ZADDITIONALSTRING, ZADDITIONALACTIONSTRING,
                   ZNAME, ZNAME1, ZBUNDLEIDENTIFIER
              FROM ZBTTBASEENTITY
             WHERE Z_ENT = 9
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            let msg = String(cString: sqlite3_errmsg(handle))
            throw ImportError.readFailed(msg)
        }
        defer { sqlite3_finalize(stmt) }

        var triggers: [Trigger] = []
        var skipped: [ImportResult.Skip] = []

        while sqlite3_step(stmt) == SQLITE_ROW {
            let pk = sqlite3_column_int(stmt, 0)
            let gestureType = sqlite3_column_int(stmt, 1)
            let actionCode = sqlite3_column_int(stmt, 2)
            let shortcut = textColumn(stmt, 3)
            let additional = textColumn(stmt, 4)
            let additionalAction = textColumn(stmt, 5)
            let name = textColumn(stmt, 6)
            let name1 = textColumn(stmt, 7)
            let bundleID = textColumn(stmt, 8)

            do {
                let trigger = try map(
                    pk: pk,
                    gestureType: gestureType,
                    actionCode: actionCode,
                    shortcut: shortcut,
                    additional: additional,
                    additionalAction: additionalAction,
                    name: name.isEmpty ? name1 : name,
                    bundleID: bundleID
                )
                triggers.append(trigger)
            } catch let MapError.skip(reason) {
                skipped.append(.init(id: pk, gestureType: gestureType, actionCode: actionCode, reason: reason))
            } catch {
                skipped.append(.init(id: pk, gestureType: gestureType, actionCode: actionCode, reason: "\(error)"))
            }
        }

        return ImportResult(triggers: triggers, skipped: skipped)
    }

    // MARK: - Mapping

    private enum MapError: Error { case skip(String) }

    private func map(
        pk: Int32,
        gestureType: Int32,
        actionCode: Int32,
        shortcut: String,
        additional: String,
        additionalAction: String,
        name: String,
        bundleID: String
    ) throws -> Trigger {
        // Choose input source: keyboard shortcut takes precedence
        let input: TriggerInput
        if !shortcut.isEmpty {
            input = try parseShortcutAsHotkey(shortcut)
        } else if let gesture = mapGestureType(gestureType) {
            input = .trackpad(gesture)
        } else {
            throw MapError.skip("unrecognized gesture type \(gestureType)")
        }

        let action = try mapAction(code: actionCode, additional: additional, additionalAction: additionalAction)

        let scope: Scope
        if bundleID.isEmpty || bundleID.hasPrefix("BT.") {
            scope = .global
        } else {
            scope = .app(bundleID: bundleID)
        }

        let displayName: String
        if !name.isEmpty {
            displayName = name
        } else {
            displayName = "Imported #\(pk)"
        }

        return Trigger(
            name: displayName,
            enabled: true,
            scope: scope,
            input: input,
            action: action
        )
    }

    /// BTT stores hotkeys as a comma-separated list of virtual key codes; modifier keys (e.g. 55=Cmd)
    /// appear alongside the trigger key (e.g. 49=Space) → "55,49".
    private func parseShortcutAsHotkey(_ shortcut: String) throws -> TriggerInput {
        let codes = shortcut
            .split(separator: ",")
            .compactMap { UInt32($0.trimmingCharacters(in: .whitespaces)) }

        var modifiers: UInt32 = 0
        var keyCode: UInt32?

        for code in codes {
            if let flag = modifierFlag(forKeyCode: code) {
                modifiers |= flag
            } else {
                keyCode = code
            }
        }

        guard let kc = keyCode else {
            throw MapError.skip("shortcut had no non-modifier key")
        }
        return .hotkey(Hotkey(keyCode: kc, modifiers: modifiers))
    }

    /// Returns the Cocoa modifier-flag bit corresponding to a modifier *virtual key code*
    /// (e.g. kVK_Command = 55). Non-modifier keycodes return nil.
    private func modifierFlag(forKeyCode code: UInt32) -> UInt32? {
        switch code {
        case 54, 55: return UInt32(NSEvent.ModifierFlags.command.rawValue)     // L/R Command
        case 56, 60: return UInt32(NSEvent.ModifierFlags.shift.rawValue)       // L/R Shift
        case 58, 61: return UInt32(NSEvent.ModifierFlags.option.rawValue)      // L/R Option
        case 59, 62: return UInt32(NSEvent.ModifierFlags.control.rawValue)     // L/R Control
        case 63:     return UInt32(NSEvent.ModifierFlags.function.rawValue)    // Fn
        default:     return nil
        }
    }

    /// Best-effort mapping of BTT internal gesture type IDs to our model.
    /// Returns nil for IDs we don't recognize (caller will skip them).
    private func mapGestureType(_ id: Int32) -> TrackpadGesture? {
        // These mappings are inferred from the user's existing config:
        //   110 had display name "3 Finger Tap → Middle Click (Close Tabs)".
        //   102/103/104 appear alongside as a related cluster (likely 3-finger swipes).
        // BTT's full mapping is undocumented; unknown IDs are skipped and reported.
        switch id {
        case 110: return TrackpadGesture(kind: .tap, fingerCount: 3)
        case 102: return TrackpadGesture(kind: .swipeUp, fingerCount: 3)
        case 103: return TrackpadGesture(kind: .swipeDown, fingerCount: 3)
        case 104: return TrackpadGesture(kind: .swipeLeft, fingerCount: 3)
        case 105: return TrackpadGesture(kind: .swipeRight, fingerCount: 3)
        // Best-guess 4-finger range; verify against your config.
        case 210: return TrackpadGesture(kind: .tap, fingerCount: 4)
        case 202: return TrackpadGesture(kind: .swipeUp, fingerCount: 4)
        case 203: return TrackpadGesture(kind: .swipeDown, fingerCount: 4)
        case 204: return TrackpadGesture(kind: .swipeLeft, fingerCount: 4)
        case 205: return TrackpadGesture(kind: .swipeRight, fingerCount: 4)
        default:  return nil
        }
    }

    /// BTT action code 366 is the most common "send shortcut / insert text" action.
    /// Without a definitive opcode table, we treat known codes pragmatically and skip the rest.
    private func mapAction(code: Int32, additional: String, additionalAction: String) throws -> Action {
        switch code {
        case 366:
            // ADDITIONALSTRING may carry "SPACE", "MIDDLE_CLICK", single char text, etc.
            let upper = additional.uppercased()
            switch upper {
            case "MIDDLE_CLICK", "MIDDLECLICK":
                return .sendMouseClick(button: .middle)
            case "RIGHT_CLICK", "RIGHTCLICK":
                return .sendMouseClick(button: .right)
            case "LEFT_CLICK", "LEFTCLICK":
                return .sendMouseClick(button: .left)
            case "SPACE":
                return .sendKeystroke(keyCode: 49, modifiers: 0)
            default:
                if additional.isEmpty {
                    throw MapError.skip("action 366 with no payload (output may live in an unread BLOB)")
                }
                return .sendText(additional)
            }
        case 251:
            // Empirically: middle click (close tab) — common BTT default.
            return .sendMouseClick(button: .middle)
        case 107:
            // Empirically: trigger named action / launch app — without ground truth, skip safely.
            throw MapError.skip("action 107 (likely 'trigger named action') — needs manual recreation")
        case 345:
            throw MapError.skip("action 345 — unknown")
        case 1:
            throw MapError.skip("action 1 — unknown / no-op")
        case -1:
            throw MapError.skip("action -1 — placeholder / disabled")
        default:
            throw MapError.skip("unknown action code \(code)")
        }
    }

    private func textColumn(_ stmt: OpaquePointer?, _ index: Int32) -> String {
        guard let cStr = sqlite3_column_text(stmt, index) else { return "" }
        return String(cString: cStr)
    }
}
