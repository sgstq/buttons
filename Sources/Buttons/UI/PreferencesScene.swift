import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct PreferencesScene: View {
    @EnvironmentObject var store: TriggerStore
    @EnvironmentObject var engine: TriggerEngine
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var permissions: PermissionsCoordinatorBox

    @State private var selection: Trigger.ID?
    @State private var editing: Trigger?
    @State private var editorPresented = false
    @State private var importPresented: ImportSource?

    enum ImportSource: Identifiable {
        case sqlite
        case json(URL)
        var id: String {
            switch self {
            case .sqlite: return "sqlite"
            case .json(let url): return "json:\(url.path)"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                PermissionsBanner()
                TriggerListView(selection: $selection) { trigger in
                    editing = trigger
                    editorPresented = true
                }
            }
            .frame(minWidth: 320)
        } detail: {
            if let id = selection, let trigger = store.triggers.first(where: { $0.id == id }) {
                TriggerDetailView(trigger: trigger)
                    .padding()
            } else {
                ContentUnavailableView(
                    "Select a trigger",
                    systemImage: "command.square",
                    description: Text("Click + to add a new keyboard or trackpad trigger.")
                )
            }
        }
        .frame(minWidth: 780, minHeight: 480)
        .toolbar {
            ToolbarItem {
                Button {
                    editing = nil
                    editorPresented = true
                } label: {
                    Label("Add Trigger", systemImage: "plus")
                }
            }
            ToolbarItem {
                Menu {
                    Button("From BetterTouchTool database") {
                        importPresented = .sqlite
                    }
                    Button("From BTT JSON file…") {
                        pickJSONFile()
                    }
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
            }
            ToolbarItem {
                Toggle(isOn: Binding(
                    get: { !engine.isPaused },
                    set: { engine.setPaused(!$0) }
                )) {
                    Label(engine.isPaused ? "Paused" : "Enabled",
                          systemImage: engine.isPaused ? "pause.circle" : "play.circle")
                }
                .toggleStyle(.switch)
            }
            ToolbarItem {
                Menu {
                    Toggle("Show menu bar icon", isOn: $settings.menuBarVisible)
                    if !settings.menuBarVisible {
                        Text("Re-launch Buttons to reopen Preferences when the icon is hidden.")
                    }
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .sheet(isPresented: $editorPresented) {
            TriggerEditorView(initial: editing) {
                editorPresented = false
            }
            .environmentObject(store)
        }
        .sheet(item: $importPresented) { source in
            switch source {
            case .sqlite:
                ImportPreviewSheet(
                    title: "Import from BetterTouchTool database",
                    subtitle: "Reads the latest btt_data_store.* file in your BTT support directory.",
                    load: {
                        await Task.detached(priority: .userInitiated) {
                            do { return .success(ImportPreview(from: try BTTImporter().read())) }
                            catch { return .failure(error) }
                        }.value
                    },
                    onCommit: { triggers in
                        for t in triggers { store.upsert(t) }
                        importPresented = nil
                    },
                    onCancel: { importPresented = nil }
                )

            case .json(let url):
                ImportPreviewSheet(
                    title: "Import from BTT JSON",
                    subtitle: url.lastPathComponent,
                    load: {
                        await Task.detached(priority: .userInitiated) {
                            do { return .success(ImportPreview(from: try BTTJSONImporter().read(from: url))) }
                            catch { return .failure(error) }
                        }.value
                    },
                    onCommit: { triggers in
                        for t in triggers { store.upsert(t) }
                        importPresented = nil
                    },
                    onCancel: { importPresented = nil }
                )
            }
        }
    }

    private func pickJSONFile() {
        let panel = NSOpenPanel()
        panel.title = "Choose BTT JSON export"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if let jsonType = UTType("public.json") {
            panel.allowedContentTypes = [jsonType]
        }
        if panel.runModal() == .OK, let url = panel.url {
            importPresented = .json(url)
        }
    }
}

@MainActor
final class PermissionsCoordinatorBox: ObservableObject {
    let coordinator: PermissionsCoordinator
    @Published var granted: Bool

    init(coordinator: PermissionsCoordinator) {
        self.coordinator = coordinator
        self.granted = coordinator.accessibilityGranted()
    }

    func refresh() {
        granted = coordinator.accessibilityGranted()
    }
}

struct PermissionsBanner: View {
    @EnvironmentObject var permissions: PermissionsCoordinatorBox

    var body: some View {
        if !permissions.granted {
            VStack(alignment: .leading, spacing: 8) {
                Label("Accessibility access required", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text("Buttons needs Accessibility access to send keystrokes and clicks. Grant it in System Settings → Privacy & Security → Accessibility.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Open Settings") {
                        permissions.coordinator.openAccessibilitySettings()
                    }
                    Button("Re-check") {
                        permissions.refresh()
                    }
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
        }
    }
}
