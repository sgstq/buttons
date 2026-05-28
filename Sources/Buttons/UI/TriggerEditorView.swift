import SwiftUI

struct TriggerEditorView: View {
    @EnvironmentObject var store: TriggerStore

    let initial: Trigger?
    var onDismiss: () -> Void

    @State private var name: String = ""
    @State private var inputKind: InputKind = .hotkey
    @State private var hotkey: Hotkey?
    @State private var gesture: TrackpadGesture? = TrackpadGesture(kind: .tap, fingerCount: 3)

    @State private var isChainAction: Bool = false
    @State private var singleStep: StepDraft = StepDraft(kind: .keystroke)
    @State private var chainSteps: [StepDraft] = []

    @State private var scopeKind: ScopeKind = .global
    @State private var scopeBundleID: String = ""

    enum InputKind: String, CaseIterable, Identifiable {
        case hotkey = "Keyboard shortcut"
        case trackpad = "Trackpad gesture"
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

                if isChainAction {
                    Section("Chain (\(chainSteps.count) step\(chainSteps.count == 1 ? "" : "s"))") {
                        Text("This trigger runs the following steps in order. Chains can be edited but not created from scratch — import a chain from BetterTouchTool to start one.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach($chainSteps) { stepBinding in
                            ChainStepRow(
                                step: stepBinding,
                                index: chainSteps.firstIndex(where: { $0.id == stepBinding.wrappedValue.id }) ?? 0,
                                stepCount: chainSteps.count,
                                onMoveUp: {
                                    if let i = chainSteps.firstIndex(where: { $0.id == stepBinding.wrappedValue.id }) {
                                        moveStep(i, by: -1)
                                    }
                                },
                                onMoveDown: {
                                    if let i = chainSteps.firstIndex(where: { $0.id == stepBinding.wrappedValue.id }) {
                                        moveStep(i, by: 1)
                                    }
                                },
                                onDelete: {
                                    chainSteps.removeAll { $0.id == stepBinding.wrappedValue.id }
                                }
                            )
                        }

                        HStack {
                            Spacer()
                            Button {
                                chainSteps.append(StepDraft(kind: .keystroke))
                            } label: {
                                Label("Add step", systemImage: "plus")
                            }
                        }
                    }
                } else {
                    Section("Action") {
                        StepEditor(step: $singleStep, allowDelay: false)
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
        .frame(width: 580, height: 640)
        .onAppear { loadInitial() }
    }

    private var canSave: Bool {
        switch inputKind {
        case .hotkey: if hotkey == nil { return false }
        case .trackpad: if gesture == nil { return false }
        }
        if isChainAction {
            guard !chainSteps.isEmpty else { return false }
            return chainSteps.allSatisfy { $0.toAction() != nil }
        } else {
            return singleStep.toAction() != nil
        }
    }

    private func moveStep(_ index: Int, by delta: Int) {
        let target = index + delta
        guard target >= 0, target < chainSteps.count else { return }
        chainSteps.swapAt(index, target)
    }

    private func loadInitial() {
        guard let t = initial else {
            singleStep = StepDraft(kind: .keystroke)
            return
        }
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
        case .sequence(let steps):
            isChainAction = true
            let drafts = steps.compactMap { StepDraft.draft(from: $0) }
            chainSteps = drafts.isEmpty ? [StepDraft(kind: .keystroke)] : drafts
        case .delay:
            // Standalone delay is degenerate — treat as a one-step chain so the user can edit it.
            isChainAction = true
            chainSteps = [StepDraft.draft(from: t.action) ?? StepDraft(kind: .delay)]
        default:
            isChainAction = false
            singleStep = StepDraft.draft(from: t.action) ?? StepDraft(kind: .keystroke)
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
        if isChainAction {
            let stepActions = chainSteps.compactMap { $0.toAction() }
            guard !stepActions.isEmpty else { return }
            // Preserve the chain identity even when only one step remains.
            action = .sequence(stepActions)
        } else {
            guard let a = singleStep.toAction() else { return }
            action = a
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

// MARK: - Editable step

/// One row of an action being edited. Doubles as a single-action editor (chains disabled)
/// and as one step inside a chain (chains allow `.delay`).
struct StepDraft: Identifiable {
    let id = UUID()
    var kind: StepKind
    var hotkey: Hotkey? = nil
    var text: String = ""
    var mouseButton: MouseButton = .left
    var bundleID: String = ""
    var urlString: String = ""
    var delaySeconds: Double = 0.5

    init(kind: StepKind) {
        self.kind = kind
    }
}

enum StepKind: String, CaseIterable, Identifiable {
    case keystroke
    case text
    case click
    case launchApp
    case openURL
    case delay

    var id: String { rawValue }

    var label: String {
        switch self {
        case .keystroke: return "Send keystroke"
        case .text:      return "Send text"
        case .click:     return "Mouse click"
        case .launchApp: return "Launch app"
        case .openURL:   return "Open URL"
        case .delay:     return "Wait"
        }
    }
}

extension StepDraft {
    static func draft(from action: Action) -> StepDraft? {
        var draft: StepDraft
        switch action {
        case .sendKeystroke(let kc, let m):
            draft = StepDraft(kind: .keystroke)
            draft.hotkey = Hotkey(keyCode: kc, modifiers: m)
        case .sendText(let s):
            draft = StepDraft(kind: .text)
            draft.text = s
        case .sendMouseClick(let b):
            draft = StepDraft(kind: .click)
            draft.mouseButton = b
        case .launchApp(let bid):
            draft = StepDraft(kind: .launchApp)
            draft.bundleID = bid
        case .openURL(let url):
            draft = StepDraft(kind: .openURL)
            draft.urlString = url.absoluteString
        case .delay(let s):
            draft = StepDraft(kind: .delay)
            draft.delaySeconds = s
        case .sequence:
            // Nested sequences aren't supported in the editor.
            return nil
        }
        return draft
    }

    func toAction() -> Action? {
        switch kind {
        case .keystroke:
            guard let h = hotkey else { return nil }
            return .sendKeystroke(keyCode: h.keyCode, modifiers: h.modifiers)
        case .text:
            return text.isEmpty ? nil : .sendText(text)
        case .click:
            return .sendMouseClick(button: mouseButton)
        case .launchApp:
            let trimmed = bundleID.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : .launchApp(bundleID: trimmed)
        case .openURL:
            let trimmed = urlString.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
            return .openURL(url)
        case .delay:
            return .delay(seconds: max(0, delaySeconds))
        }
    }
}

struct ChainStepRow: View {
    @Binding var step: StepDraft
    let index: Int
    let stepCount: Int
    var onMoveUp: () -> Void
    var onMoveDown: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Step \(index + 1)")
                    .font(.headline)
                Spacer()
                Button(action: onMoveUp) {
                    Image(systemName: "arrow.up")
                }
                .buttonStyle(.borderless)
                .disabled(index == 0)
                .help("Move up")

                Button(action: onMoveDown) {
                    Image(systemName: "arrow.down")
                }
                .buttonStyle(.borderless)
                .disabled(index >= stepCount - 1)
                .help("Move down")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .disabled(stepCount <= 1)
                .help("Delete step")
            }
            StepEditor(step: $step, allowDelay: true)
        }
        .padding(.vertical, 4)
    }
}

struct StepEditor: View {
    @Binding var step: StepDraft
    let allowDelay: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Do", selection: $step.kind) {
                ForEach(availableKinds) { kind in
                    Text(kind.label).tag(kind)
                }
            }

            switch step.kind {
            case .keystroke:
                LabeledContent("Keystroke") {
                    ShortcutRecorderView(value: $step.hotkey)
                }
            case .text:
                TextField("Text to type", text: $step.text)
            case .click:
                Picker("Button", selection: $step.mouseButton) {
                    ForEach(MouseButton.allCases, id: \.self) {
                        Text($0.rawValue.capitalized).tag($0)
                    }
                }
                .pickerStyle(.segmented)
            case .launchApp:
                TextField("Bundle ID (e.g. com.apple.finder)", text: $step.bundleID)
            case .openURL:
                TextField("URL (e.g. https://example.com)", text: $step.urlString)
            case .delay:
                HStack {
                    Slider(value: $step.delaySeconds, in: 0.05...5.0, step: 0.05)
                    Text(String(format: "%.2fs", step.delaySeconds))
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 64, alignment: .trailing)
                }
            }
        }
    }

    private var availableKinds: [StepKind] {
        allowDelay ? StepKind.allCases : StepKind.allCases.filter { $0 != .delay }
    }
}
