import Foundation
import AppKit

/// Imports BetterTouchTool's JSON export format (the one produced by
/// right-clicking a trigger → "Copy as JSON" or the "Export presets" file).
///
/// Recognised:
///   - BTTTriggerTypeKeyboardShortcut  → hotkey trigger
///   - BTTPredefinedActionType 264     → "Send Shortcut to Active App" (BTTShortcutToSend)
///   - BTTPredefinedActionType 345     → Delay (BTTDelayNextActionBy seconds)
///
/// Multi-step BTTActionsToExecute arrays become `.sequence([...])` with
/// `.delay` entries interleaved for the delay actions.
final class BTTJSONImporter {
    struct ImportResult {
        var triggers: [Trigger]
        var skipped: [Skip]
        struct Skip: Identifiable {
            let id = UUID()
            let title: String
            let reason: String
        }
    }

    enum ImportError: Error, LocalizedError {
        case readFailed(String)
        case malformed(String)
        var errorDescription: String? {
            switch self {
            case .readFailed(let s): return "Failed to read JSON file: \(s)"
            case .malformed(let s):  return "Malformed BTT JSON: \(s)"
            }
        }
    }

    func read(from url: URL) throws -> ImportResult {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ImportError.readFailed(error.localizedDescription)
        }

        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ImportError.malformed(error.localizedDescription)
        }

        // BTT exports may be either a top-level array of triggers or a single trigger dict.
        let entries: [[String: Any]]
        if let array = parsed as? [[String: Any]] {
            entries = array
        } else if let dict = parsed as? [String: Any] {
            entries = [dict]
        } else {
            throw ImportError.malformed("expected array or object at top level")
        }

        var triggers: [Trigger] = []
        var skipped: [ImportResult.Skip] = []

        for entry in entries {
            let title = displayName(for: entry)
            do {
                triggers.append(try mapEntry(entry, title: title))
            } catch let MapError.skip(reason) {
                skipped.append(.init(title: title, reason: reason))
            } catch {
                skipped.append(.init(title: title, reason: "\(error)"))
            }
        }

        return ImportResult(triggers: triggers, skipped: skipped)
    }

    // MARK: - Mapping

    private enum MapError: Error { case skip(String) }

    private func mapEntry(_ entry: [String: Any], title: String) throws -> Trigger {
        let triggerClass = entry["BTTTriggerClass"] as? String ?? ""
        let input = try parseInput(triggerClass: triggerClass, entry: entry)
        let action = try parseActions(entry: entry)
        let scope = parseScope(entry: entry)
        return Trigger(name: title, scope: scope, input: input, action: action)
    }

    private func parseInput(triggerClass: String, entry: [String: Any]) throws -> TriggerInput {
        switch triggerClass {
        case "BTTTriggerTypeKeyboardShortcut":
            guard let kc = entry["BTTShortcutKeyCode"] as? Int else {
                throw MapError.skip("missing BTTShortcutKeyCode")
            }
            let mods = (entry["BTTShortcutModifierKeys"] as? Int) ?? 0
            return .hotkey(Hotkey(keyCode: UInt32(kc), modifiers: UInt32(mods)))

        default:
            throw MapError.skip("unsupported trigger class '\(triggerClass)'")
        }
    }

    private func parseActions(entry: [String: Any]) throws -> Action {
        guard let raw = entry["BTTActionsToExecute"] as? [[String: Any]], !raw.isEmpty else {
            throw MapError.skip("no BTTActionsToExecute")
        }

        let ordered = raw.sorted { lhs, rhs in
            (lhs["BTTOrder"] as? Int ?? 0) < (rhs["BTTOrder"] as? Int ?? 0)
        }

        var actions: [Action] = []
        var unmapped: [Int] = []
        for sub in ordered {
            if let a = mapAction(sub) {
                actions.append(a)
            } else {
                unmapped.append(sub["BTTPredefinedActionType"] as? Int ?? -1)
            }
        }

        guard !actions.isEmpty else {
            throw MapError.skip("none of \(ordered.count) actions are recognised (codes: \(unmapped))")
        }
        return actions.count == 1 ? actions[0] : .sequence(actions)
    }

    private func mapAction(_ json: [String: Any]) -> Action? {
        let type = json["BTTPredefinedActionType"] as? Int ?? -1
        switch type {
        case 264:
            // Send shortcut to active app. Payload in BTTShortcutToSend ("kc1,kc2,...").
            if let payload = json["BTTShortcutToSend"] as? String,
               let action = parseShortcutString(payload) {
                return action
            }
            // Some BTT versions use BTTLayoutIndependentActionChar with single chars.
            if let ch = json["BTTLayoutIndependentActionChar"] as? String, !ch.isEmpty {
                return .sendText(ch)
            }
            return nil

        case 345:
            // Delay / pause execution. BTTDelayNextActionBy seconds (string or number).
            if let secsStr = json["BTTDelayNextActionBy"] as? String, let secs = Double(secsStr) {
                return .delay(seconds: secs)
            }
            if let secs = json["BTTDelayNextActionBy"] as? Double {
                return .delay(seconds: secs)
            }
            if let secs = json["BTTDelayNextActionBy"] as? Int {
                return .delay(seconds: Double(secs))
            }
            return nil

        default:
            return nil
        }
    }

    /// Parses a BTT shortcut payload like "55,49" → ⌘+Space into a sendKeystroke action.
    private func parseShortcutString(_ s: String) -> Action? {
        let codes = s
            .split(separator: ",")
            .compactMap { UInt32($0.trimmingCharacters(in: .whitespaces)) }

        var mods: UInt32 = 0
        var key: UInt32?

        for code in codes {
            if let flag = modifierFlag(forKeyCode: code) {
                mods |= flag
            } else {
                key = code
            }
        }
        guard let k = key else { return nil }
        return .sendKeystroke(keyCode: k, modifiers: mods)
    }

    private func modifierFlag(forKeyCode code: UInt32) -> UInt32? {
        switch code {
        case 54, 55: return UInt32(NSEvent.ModifierFlags.command.rawValue)
        case 56, 60: return UInt32(NSEvent.ModifierFlags.shift.rawValue)
        case 58, 61: return UInt32(NSEvent.ModifierFlags.option.rawValue)
        case 59, 62: return UInt32(NSEvent.ModifierFlags.control.rawValue)
        case 63:     return UInt32(NSEvent.ModifierFlags.function.rawValue)
        default:     return nil
        }
    }

    private func parseScope(entry: [String: Any]) -> Scope {
        // BTT often stores a per-app config separately; the JSON export may include
        // BTTRestrictedToApps or BTTBundleIdentifier. Default to global if missing.
        if let bid = entry["BTTBundleIdentifier"] as? String, !bid.isEmpty {
            return .app(bundleID: bid)
        }
        return .global
    }

    private func displayName(for entry: [String: Any]) -> String {
        if let n = entry["BTTNotes"] as? String, !n.isEmpty { return n }
        if let n = entry["BTTGenericActionConfig"] as? String, !n.isEmpty { return n }
        if let uuid = entry["BTTUUID"] as? String, !uuid.isEmpty {
            return "Imported \(uuid.prefix(8))"
        }
        return "Imported BTT trigger"
    }
}
