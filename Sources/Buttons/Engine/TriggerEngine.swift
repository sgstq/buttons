import Foundation
import Combine

@MainActor
final class TriggerEngine: ObservableObject {
    @Published private(set) var isPaused = false

    private let store: TriggerStore
    private let context: ContextProvider
    private let dispatcher: ActionDispatcher
    private let hotkeys = HotkeyMonitor()
    private let trackpad = TrackpadMonitor()
    private var cancellables = Set<AnyCancellable>()

    init(store: TriggerStore, context: ContextProvider, dispatcher: ActionDispatcher) {
        self.store = store
        self.context = context
        self.dispatcher = dispatcher
    }

    func start() {
        rebuild()
        store.$triggers
            .dropFirst()
            .sink { [weak self] _ in self?.rebuild() }
            .store(in: &cancellables)
    }

    func setPaused(_ paused: Bool) {
        guard paused != isPaused else { return }
        isPaused = paused
        rebuild()
    }

    private func rebuild() {
        hotkeys.unregisterAll()
        trackpad.stop()
        trackpad.clearHandlers()

        guard !isPaused else { return }

        for trigger in store.triggers where trigger.enabled {
            switch trigger.input {
            case .hotkey(let h):
                hotkeys.register(hotkey: h) { [weak self] in
                    self?.fire(trigger)
                }
            case .trackpad(let g):
                trackpad.register(gesture: g) { [weak self] in
                    self?.fire(trigger)
                }
            }
        }

        if trackpad.hasHandlers {
            trackpad.start()
        }
    }

    private func fire(_ trigger: Trigger) {
        guard !isPaused else { return }
        guard trigger.scope.matches(frontmostBundleID: context.currentBundleID) else { return }
        dispatcher.dispatch(trigger.action)
    }
}
