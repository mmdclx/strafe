import Foundation
import CoreGraphics
import OpenMultitouchSupport

@MainActor
final class MultitouchGestureEngine: GestureDetecting {
    var onGesture: ((GestureEvent) -> Void)?
    var onDebugState: ((GestureDebugState) -> Void)?

    private let classifier = GestureClassifier()
    private let manager = OMSManager.shared
    private var listenerTask: Task<Void, Never>?

    func start() {
        guard listenerTask == nil else { return }
        let started = manager.startListening()
        if !started {
            Log.info(Log.gesture, "Failed to start multitouch listener")
            return
        }

        listenerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await touches in manager.touchDataStream {
                let now = ProcessInfo.processInfo.systemUptime
                let samples = touches.compactMap { touch -> TouchSample? in
                    guard let phase = TouchPhase(touch.state) else { return nil }
                    return TouchSample(
                        id: Int(touch.id),
                        position: CGPoint(x: CGFloat(touch.position.x), y: CGFloat(touch.position.y)),
                        phase: phase
                    )
                }
                let result = self.classifier.process(samples: samples, now: now)
                if let event = result.0 {
                    self.onGesture?(event)
                }
                self.onDebugState?(result.1)
            }
        }

        Log.info(Log.gesture, "OpenMultitouchSupport listener started")
    }

    func stop() {
        listenerTask?.cancel()
        listenerTask = nil
        _ = manager.stopListening()
        Log.info(Log.gesture, "OpenMultitouchSupport listener stopped")
    }
}

private extension TouchPhase {
    init?(_ state: OMSState) {
        switch state {
        case .notTouching:
            return nil
        case .starting:
            self = .starting
        case .hovering:
            self = .hovering
        case .making:
            self = .making
        case .touching:
            self = .touching
        case .breaking:
            self = .breaking
        case .lingering:
            self = .lingering
        case .leaving:
            self = .leaving
        }
    }
}
