import SwiftUI
import AppKit

/// Generic preview-and-commit sheet for any importer that returns triggers + skipped diagnostics.
struct ImportPreviewSheet: View {
    let title: String
    let subtitle: String?
    let load: () async -> Result<ImportPreview, Error>

    var onCommit: ([Trigger]) -> Void
    var onCancel: () -> Void

    @State private var state: ViewState = .loading

    enum ViewState {
        case loading
        case failed(String)
        case loaded(ImportPreview)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2)
            if let subtitle = subtitle {
                Text(subtitle).font(.callout).foregroundStyle(.secondary)
            }

            Group {
                switch state {
                case .loading:
                    ProgressView("Reading…")
                        .frame(maxWidth: .infinity, alignment: .center)
                case .failed(let msg):
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Import failed", systemImage: "exclamationmark.octagon")
                            .foregroundStyle(.red)
                        Text(msg).font(.callout)
                    }
                case .loaded(let preview):
                    previewView(preview)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Import \(loadedCount) triggers") {
                    if case .loaded(let p) = state { onCommit(p.triggers) }
                }
                .disabled(loadedCount == 0)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 640, height: 520)
        .task {
            switch await load() {
            case .success(let preview): state = .loaded(preview)
            case .failure(let err):     state = .failed(err.localizedDescription)
            }
        }
    }

    private var loadedCount: Int {
        if case .loaded(let p) = state { return p.triggers.count }
        return 0
    }

    @ViewBuilder
    private func previewView(_ preview: ImportPreview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("\(preview.triggers.count) ready to import", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Spacer()
                if !preview.skipped.isEmpty {
                    Label("\(preview.skipped.count) skipped", systemImage: "questionmark.diamond.fill")
                        .foregroundStyle(.orange)
                }
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if !preview.triggers.isEmpty {
                        Text("Will import").font(.headline).padding(.top, 4)
                        ForEach(preview.triggers) { t in
                            HStack(alignment: .top) {
                                Image(systemName: "checkmark.circle").foregroundStyle(.green)
                                VStack(alignment: .leading) {
                                    Text(t.name).font(.body)
                                    Text("\(t.input.summary) → \(t.action.summary)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    if !preview.skipped.isEmpty {
                        Text("Skipped").font(.headline).padding(.top, 12)
                        ForEach(preview.skipped) { s in
                            HStack(alignment: .top) {
                                Image(systemName: "questionmark.circle").foregroundStyle(.orange)
                                VStack(alignment: .leading) {
                                    Text(s.title).font(.body)
                                    Text(s.reason).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .background(Color.gray.opacity(0.06))
            .cornerRadius(6)
        }
    }
}

/// Normalized payload that ImportPreviewSheet renders.
struct ImportPreview {
    var triggers: [Trigger]
    var skipped: [Skip]

    struct Skip: Identifiable {
        let id = UUID()
        let title: String
        let reason: String
    }
}

extension ImportPreview {
    init(from sqlite: BTTImporter.ImportResult) {
        self.triggers = sqlite.triggers
        self.skipped = sqlite.skipped.map { s in
            Skip(title: "Row \(s.id) (gesture \(s.gestureType), action \(s.actionCode))", reason: s.reason)
        }
    }

    init(from json: BTTJSONImporter.ImportResult) {
        self.triggers = json.triggers
        self.skipped = json.skipped.map { s in Skip(title: s.title, reason: s.reason) }
    }
}
