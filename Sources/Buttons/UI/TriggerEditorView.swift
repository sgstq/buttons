import SwiftUI

struct TriggerEditorView: View {
    @EnvironmentObject var store: TriggerStore

    let initial: Trigger?
    var onDismiss: () -> Void

    @State private var name: String = ""
    @State private var inputKind: InputKind = .hotkey
    @State private var hotkey: Hotkey?
    @State private var gesture: TrackpadGesture? = TrackpadGesture(kind: .tap, fingerCount: 3)

    @State private var actionKind: ActionKind = .keystroke
    @State private var actionHotkey: Hotkey?
    @State private var actionText: String = ""
    @State private var actionMouseButton: MouseButton = .middle

    /// True when the existing trigger's action is a chain (or other non-editable form).
    /// We preserve it as-is and only let the user edit name / input / scope.
    @State private var preservedAction: Action?

    @State private var scopeKind: ScopeKind = .global
    @State private var scopeBundleID: String = ""

    enum InputKind: String, CaseIterable, Identifiable {
        case hotkey = "Keyboard shortcut"
        case trackpad = "Trackpad gesture"
        var id: String { rawValue }
    }
    enum ActionKind: String, CaseIterable, Identifiable {
        case keystroke = "Send keystroke"
        case text = "Send text"
        case click = "Mouse click"
        var id: String { rawValue }
    }
    enum ScopeKind: String, CaseIterable, Identifiable {
        case global = "Global"
        case app = "Specific app"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(initial == nil ? "New Trigger" : "Edit Trigger")
                .font(.title2)

            Form {
                Section {
                    TextField("Name (optional)", text: $name)
                }

                Section("Trigger") {
                    Picker("When", selection: $inputKind) {
                        ForEach(InputKind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch inputKind {
                    case .hotkey:
                        LabeledContent("Shortcut") {
                            ShortcutRecorderView(value: $hotkey)
                        }
                    case .trackpad:
                        GestureRecorderView(value: $gesture)
                    }
                }

                if let preserved = preservedAction {
                    Section("Action") {
                        Label("Multi-step chain", systemImage: "lock")
                            .foregroundStyle(.secondary)
                        Text(preserved.summary)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(4)
                        Text("Chain editing isn't supported yet. Saving keeps the existing action. To rebuild, delete this trigger and re-import.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Section("Action") {
                        Picker("Do", selection: $actionKind) {
                            ForEach(ActionKind.allCases) { Text($0.rawValue).tag($0) }
                        }
                        switch actionKind {
                        case .keystroke:
                            LabeledContent("Keystroke") {
                                ShortcutRecorderView(value: $actionHotkey)
                            }
                        case .text:
                            TextField("Text to type", text: $actionText)
                        case .click:
                            Picker("Button", selection: $actionMouseButton) {
                                ForEach(MouseButton.allCases, id: \.self) {
                                    Text($0.rawValue.capitalized).tag($0)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }

                Section("Scope") {
                    Picker("Apply", selection: $scopeKind) {
                        ForEach(ScopeKind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if scopeKind == .app {
                        TextField("Bundle ID (e.g. com.apple.finder)", text: $scopeBundleID)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { onDismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if let initial = initial {
                    Button("Delete", role: .destructive) {
                        store.remove(initial.id)
                        onDismiss()
                    }
                }
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 540, height: 540)
        .onAppear { loadInitial() }
    }

    private var canSave: Bool {
        switch inputKind {
        case .hotkey: if hotkey == nil { return false }
        case .trackpad: if gesture == nil { return false }
        }
        if preservedAction != nil { return true }
        switch actionKind {
        case .keystroke: return actionHotkey != nil
        case .text: return !actionText.isEmpty
        case .click: return true
        }
    }

    private func loadInitial() {
        guard let t = initial else { return }
        name = t.name

        switch t.input {
        case .hotkey(let h):
            inputKind = .hotkey
            hotkey = h
        case .trackpad(let g):
            inputKind = .trackpad
            gesture = g
        }

        switch t.action {
        case .sendKeystroke(let kc, let m):
            actionKind = .keystroke
            actionHotkey = Hotkey(keyCode: kc, modifiers: m)
        case .sendText(let s):
            actionKind = .text
            actionText = s
        case .sendMouseClick(let b):
            actionKind = .click
            actionMouseButton = b
        case .sequence, .delay, .launchApp, .openURL:
            // Non-editable in the Phase 1 UI — preserve and lock the action section.
            preservedAction = t.action
        }

        switch t.scope {
        case .global:
            scopeKind = .global
        case .app(let bid):
            scopeKind = .app
            scopeBundleID = bid
        }
    }

    private func save() {
        let input: TriggerInput
        switch inputKind {
        case .hotkey:
            guard let h = hotkey else { return }
            input = .hotkey(h)
        case .trackpad:
            guard let g = gesture else { return }
            input = .trackpad(g)
        }

        let action: Action
        if let preserved = preservedAction {
            action = preserved
        } else {
            switch actionKind {
            case .keystroke:
                guard let h = actionHotkey else { return }
                action = .sendKeystroke(keyCode: h.keyCode, modifiers: h.modifiers)
            case .text:
                action = .sendText(actionText)
            case .click:
                action = .sendMouseClick(button: actionMouseButton)
            }
        }

        let scope: Scope = scopeKind == .global
            ? .global
            : .app(bundleID: scopeBundleID.trimmingCharacters(in: .whitespaces))

        let trigger = Trigger(
            id: initial?.id ?? UUID(),
            name: name,
            enabled: initial?.enabled ?? true,
            scope: scope,
            input: input,
            action: action
        )
        store.upsert(trigger)
        onDismiss()
    }
}
