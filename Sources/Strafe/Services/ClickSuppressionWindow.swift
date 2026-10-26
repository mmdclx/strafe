import Foundation

/// Timing policy shared by the event callback and expiry timer. The owner supplies
/// monotonic time and serializes access; this type does not install an event tap.
struct ClickSuppressionWindow {
    private var deadline: TimeInterval?

    mutating func extend(for duration: TimeInterval, now: TimeInterval) -> TimeInterval {
        let nextDeadline = max(deadline ?? now, now + duration)
        deadline = nextDeadline
        return nextDeadline
    }

    func isSuppressing(at now: TimeInterval) -> Bool {
        deadline.map { now < $0 } ?? false
    }

    mutating func expire(for scheduledDeadline: TimeInterval, now: TimeInterval) -> Bool {
        guard scheduledDeadline == deadline, !isSuppressing(at: now) else { return false }
        deadline = nil
        return true
    }

    mutating func reset() {
        deadline = nil
    }
}
