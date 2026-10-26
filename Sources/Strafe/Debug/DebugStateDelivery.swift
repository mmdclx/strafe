import Foundation

/// Coalesces live input without dropping the final frame when touch callbacks stop.
@MainActor
final class DebugStateDelivery {
    private var nextUpdateAt: TimeInterval = 0
    private var pending: GestureDebugState?
    private var task: Task<Void, Never>?
    private var receive: ((GestureDebugState) -> Void)?

    func start(receive: @escaping (GestureDebugState) -> Void) {
        stop()
        self.receive = receive
    }

    func stop() {
        task?.cancel()
        task = nil
        pending = nil
        receive = nil
        nextUpdateAt = 0
    }

    func submit(_ state: GestureDebugState) {
        guard receive != nil else { return }
        pending = state
        let now = ProcessInfo.processInfo.systemUptime
        if now >= nextUpdateAt {
            task?.cancel()
            task = nil
            deliver()
        } else if task == nil {
            let delay = nextUpdateAt - now
            task = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                guard let self, !Task.isCancelled else { return }
                self.task = nil
                self.deliver()
            }
        }
    }

    private func deliver() {
        guard let state = pending else { return }
        pending = nil
        nextUpdateAt = ProcessInfo.processInfo.systemUptime + AppConstants.debugOverlayUpdateIntervalSeconds
        receive?(state)
    }
}
