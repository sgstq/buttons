import Foundation
import Combine

@MainActor
final class TriggerStore: ObservableObject {
    @Published private(set) var triggers: [Trigger] = []

    private let url: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("Buttons", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.url = dir.appendingPathComponent("triggers.json")
    }

    func load() {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            triggers = try JSONDecoder().decode([Trigger].self, from: data)
        } catch {
            NSLog("Buttons: failed to load triggers: \(error)")
        }
    }

    func save() {
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try enc.encode(triggers)
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("Buttons: failed to save triggers: \(error)")
        }
    }

    func upsert(_ trigger: Trigger) {
        if let idx = triggers.firstIndex(where: { $0.id == trigger.id }) {
            triggers[idx] = trigger
        } else {
            triggers.append(trigger)
        }
        save()
    }

    func remove(_ id: Trigger.ID) {
        triggers.removeAll { $0.id == id }
        save()
    }

    func replaceAll(with newTriggers: [Trigger]) {
        triggers = newTriggers
        save()
    }
}
