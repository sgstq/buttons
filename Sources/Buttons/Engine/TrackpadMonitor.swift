import Foundation
import MultitouchBridge

/// Classifies multitouch events into gestures (tap / swipe N-finger) and routes them to handlers.
@MainActor
final class TrackpadMonitor: NSObject, BTNTrackpadDelegate {
    private let bridge = BTNTrackpadMonitor()
    private var handlers: [TrackpadGesture: () -> Void] = [:]
    private var running = false

    // Gesture state-machine
    private var lastActive: Int = 0
    private var maxActive: Int = 0
    private var startTime: Double = 0
    private var startPositions: [Int: (x: Double, y: Double)] = [:]
    private var lastPositions: [Int: (x: Double, y: Double)] = [:]

    /// Tap must complete within this window (seconds).
    private let tapWindow: Double = 0.25
    /// Maximum drift (normalized 0..1) per finger to still count as a tap.
    private let tapMaxDrift: Double = 0.04
    /// Minimum drift to count as a swipe.
    private let swipeMinDrift: Double = 0.08

    override init() {
        super.init()
        bridge.delegate = self
    }

    var hasHandlers: Bool { !handlers.isEmpty }

    func register(gesture: TrackpadGesture, handler: @escaping () -> Void) {
        handlers[gesture] = handler
    }

    func clearHandlers() {
        handlers.removeAll()
    }

    func start() {
        guard !running else { return }
        if bridge.start() {
            running = true
        } else {
            NSLog("Buttons: trackpad monitor failed to start (private framework unavailable or no devices)")
        }
    }

    func stop() {
        guard running else { return }
        bridge.stop()
        running = false
        resetState()
    }

    // MARK: - BTNTrackpadDelegate

    nonisolated func trackpadDidUpdate(
        withTouches touches: [BTNTouch],
        activeCount: Int,
        timestamp: Double
    ) {
        // The bridge already dispatches us to the main queue.
        MainActor.assumeIsolated {
            self.handleUpdate(touches: touches, activeCount: activeCount, timestamp: timestamp)
        }
    }

    private func handleUpdate(touches: [BTNTouch], activeCount n: Int, timestamp: Double) {
        // Track positions of every touch we see
        for t in touches {
            let id = t.identifier
            let pos = (x: t.x, y: t.y)
            lastPositions[id] = pos
            if startPositions[id] == nil {
                startPositions[id] = pos
            }
        }

        if n > 0 && lastActive == 0 {
            // Gesture begins
            startTime = timestamp
            maxActive = n
        } else if n > 0 {
            maxActive = max(maxActive, n)
        } else if n == 0 && lastActive > 0 {
            // Gesture ended: classify
            let duration = timestamp - startTime
            let fingers = maxActive

            if fingers >= 2 && fingers <= 5 {
                classify(fingers: fingers, duration: duration)
            }
            resetState()
        }
        lastActive = n
    }

    private func classify(fingers: Int, duration: Double) {
        // Average per-finger drift (start → last)
        var dxSum = 0.0, dySum = 0.0, count = 0
        for (id, start) in startPositions {
            if let last = lastPositions[id] {
                dxSum += last.x - start.x
                dySum += last.y - start.y
                count += 1
            }
        }
        guard count > 0 else { return }
        let dx = dxSum / Double(count)
        let dy = dySum / Double(count)
        let drift = (dx * dx + dy * dy).squareRoot()

        // Tap: quick, low drift
        if duration < tapWindow && drift < tapMaxDrift {
            fire(TrackpadGesture(kind: .tap, fingerCount: fingers))
            return
        }

        // Swipe: dominant axis
        if drift >= swipeMinDrift {
            let kind: TrackpadGesture.Kind
            if abs(dx) > abs(dy) {
                kind = dx > 0 ? .swipeRight : .swipeLeft
            } else {
                // Trackpad y is inverted on macOS (top is 1.0 in some readings, 0 in others).
                // Empirically: increasing y == moving toward top of trackpad == swipe up.
                kind = dy > 0 ? .swipeUp : .swipeDown
            }
            fire(TrackpadGesture(kind: kind, fingerCount: fingers))
        }
    }

    private func fire(_ g: TrackpadGesture) {
        guard let h = handlers[g] else { return }
        h()
    }

    private func resetState() {
        lastActive = 0
        maxActive = 0
        startTime = 0
        startPositions.removeAll()
        lastPositions.removeAll()
    }
}
