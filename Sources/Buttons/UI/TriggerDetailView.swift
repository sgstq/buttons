import SwiftUI

struct TriggerDetailView: View {
    let trigger: Trigger

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(trigger.name.isEmpty ? "(unnamed)" : trigger.name)
                .font(.title2)

            GroupBox("When") {
                Text(trigger.input.summary)
                    .font(.system(.body, design: .monospaced))
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Do") {
                actionView(trigger.action)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            GroupBox("Scope") {
                Text(trigger.scope.summary)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func actionView(_ action: Action) -> some View {
        if case .sequence(let steps) = action {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(idx + 1).")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, alignment: .trailing)
                        Text(step.summary)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
        } else {
            Text(action.summary)
                .font(.system(.body, design: .monospaced))
        }
    }
}
