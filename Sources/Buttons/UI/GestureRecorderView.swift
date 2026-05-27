import SwiftUI

struct GestureRecorderView: View {
    @Binding var value: TrackpadGesture?

    @State private var fingers: Int = 3
    @State private var kind: TrackpadGesture.Kind = .tap

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("Fingers") {
                Picker("", selection: $fingers) {
                    Text("2").tag(2)
                    Text("3").tag(3)
                    Text("4").tag(4)
                    Text("5").tag(5)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                .labelsHidden()
            }

            LabeledContent("Gesture") {
                Picker("", selection: $kind) {
                    Text("Tap").tag(TrackpadGesture.Kind.tap)
                    Text("Swipe up").tag(TrackpadGesture.Kind.swipeUp)
                    Text("Swipe down").tag(TrackpadGesture.Kind.swipeDown)
                    Text("Swipe left").tag(TrackpadGesture.Kind.swipeLeft)
                    Text("Swipe right").tag(TrackpadGesture.Kind.swipeRight)
                }
                .labelsHidden()
                .frame(width: 220)
            }
        }
        .onAppear { syncFromValue() }
        .onChange(of: fingers) { _, _ in publish() }
        .onChange(of: kind) { _, _ in publish() }
    }

    private func syncFromValue() {
        if let v = value {
            fingers = v.fingerCount
            kind = v.kind
        } else {
            publish()
        }
    }

    private func publish() {
        value = TrackpadGesture(kind: kind, fingerCount: fingers)
    }
}
