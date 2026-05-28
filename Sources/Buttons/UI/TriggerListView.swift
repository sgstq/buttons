import SwiftUI

struct TriggerListView: View {
    @EnvironmentObject var store: TriggerStore
    @Binding var selection: Trigger.ID?
    var onEdit: (Trigger) -> Void

    var body: some View {
        List(selection: $selection) {
            if store.triggers.isEmpty {
                Text("No triggers yet")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(store.triggers) { trigger in
                    TriggerRow(trigger: trigger)
                        .tag(trigger.id)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { onEdit(trigger) }
                        .contextMenu {
                            Button("Edit…") { onEdit(trigger) }
                            Divider()
                            Button("Delete", role: .destructive) {
                                store.remove(trigger.id)
                            }
                        }
                }
            }
        }
        .listStyle(.sidebar)
    }
}

private struct TriggerRow: View {
    @EnvironmentObject var store: TriggerStore
    let trigger: Trigger

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { trigger.enabled },
                set: { newValue in
                    var t = trigger
                    t.enabled = newValue
                    store.upsert(t)
                }
            ))
            .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                    .font(.body)
                    .lineLimit(1)
                Text(trigger.action.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if case .app = trigger.scope {
                Image(systemName: "app.badge")
                    .foregroundStyle(.tertiary)
                    .help(trigger.scope.summary)
            }
        }
        .padding(.vertical, 2)
    }

    private var displayTitle: String {
        trigger.name.isEmpty ? trigger.input.summary : trigger.name
    }
}
