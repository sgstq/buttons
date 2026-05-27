import SwiftUI
import AppKit

struct ShortcutRecorderView: View {
    @Binding var value: Hotkey?

    @State private var recording = false
    @State private var localMonitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Button(action: toggle) {
                Text(label)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(minWidth: 140)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(recording ? Color.accentColor.opacity(0.18) : Color.gray.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(recording ? Color.accentColor : Color.clear, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            if value != nil && !recording {
                Button {
                    value = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear")
            }
        }
        .onDisappear { stopRecording() }
    }

    private var label: String {
        if recording { return "Press shortcut… (esc to cancel)" }
        if let v = value { return shortcutString(v) }
        return "Click to record"
    }

    private func toggle() {
        if recording { stopRecording() } else { startRecording() }
    }

    private func startRecording() {
        recording = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // escape
                stopRecording()
                return nil
            }
            // Ignore presses of pure modifier keys (no character key chosen yet).
            let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 58, 59, 60, 61, 62, 63]
            if modifierKeyCodes.contains(event.keyCode) {
                return nil
            }
            let mods = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .rawValue
            value = Hotkey(keyCode: UInt32(event.keyCode), modifiers: UInt32(mods))
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        recording = false
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
    }
}
