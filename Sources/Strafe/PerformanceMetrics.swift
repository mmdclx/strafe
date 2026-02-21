import Foundation

final class PerformanceMetrics: @unchecked Sendable {
    static let shared = PerformanceMetrics()

    static let isEnabled: Bool = {
        #if DEBUG
        true
        #else
        let value = ProcessInfo.processInfo.environment["STRAFE_PERF_METRICS"]?.lowercased()
        return value == "1" || value == "true" || value == "yes"
        #endif
    }()

    @inline(__always)
    static func startTimestamp() -> TimeInterval? {
        guard isEnabled else { return nil }
        return ProcessInfo.processInfo.systemUptime
    }

    private struct DurationStats {
        var count: Int = 0
        var totalMs: Double = 0
        var maxMs: Double = 0

        mutating func add(durationSeconds: TimeInterval) {
            let milliseconds = durationSeconds * 1000
            count += 1
            totalMs += milliseconds
            if milliseconds > maxMs {
                maxMs = milliseconds
            }
        }

        var averageMs: Double {
            guard count > 0 else { return 0 }
            return totalMs / Double(count)
        }
    }

    private struct Snapshot {
        let windowSeconds: TimeInterval
        let touchCallbacks: Int
        let touchSamples: Int
        let gestureCandidateEvaluations: Int
        let gestureTriggers: Int
        let clickSuppressorInvocations: Int
        let clickSuppressorEvents: Int
        let clickSuppressedEvents: Int
        let frontmostQueries: Int
        let touchConversion: DurationStats
        let classifierProcess: DurationStats
        let frontmostQuery: DurationStats
        let clickSuppressorHandle: DurationStats
    }

    private let stateLock = NSLock()
    private var windowStart: TimeInterval
    private var nextEmitAt: TimeInterval

    private var touchCallbacks: Int = 0
    private var touchSamples: Int = 0
    private var gestureCandidateEvaluations: Int = 0
    private var gestureTriggers: Int = 0
    private var clickSuppressorInvocations: Int = 0
    private var clickSuppressorEvents: Int = 0
    private var clickSuppressedEvents: Int = 0
    private var frontmostQueries: Int = 0

    private var touchConversion = DurationStats()
    private var classifierProcess = DurationStats()
    private var frontmostQuery = DurationStats()
    private var clickSuppressorHandle = DurationStats()

    private init() {
        let now = ProcessInfo.processInfo.systemUptime
        windowStart = now
        nextEmitAt = now + AppConstants.performanceMetricsLogIntervalSeconds
    }

    func recordTouchCallback(sampleCount: Int) {
        updateState {
            touchCallbacks += 1
            touchSamples += sampleCount
        }
    }

    func recordGestureCandidateEvaluation() {
        updateState {
            gestureCandidateEvaluations += 1
        }
    }

    func recordGestureTrigger() {
        updateState {
            gestureTriggers += 1
        }
    }

    func recordClickSuppressorInvocation() {
        updateState {
            clickSuppressorInvocations += 1
        }
    }

    func recordClickSuppressorEvent(suppressed: Bool) {
        updateState {
            clickSuppressorEvents += 1
            if suppressed {
                clickSuppressedEvents += 1
            }
        }
    }

    func recordTouchConversion(startedAt: TimeInterval?) {
        guard let startedAt else { return }
        let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
        updateState {
            touchConversion.add(durationSeconds: elapsed)
        }
    }

    func recordClassifierProcess(startedAt: TimeInterval?) {
        guard let startedAt else { return }
        let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
        updateState {
            classifierProcess.add(durationSeconds: elapsed)
        }
    }

    func recordFrontmostQuery(startedAt: TimeInterval?) {
        guard let startedAt else { return }
        let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
        updateState {
            frontmostQueries += 1
            frontmostQuery.add(durationSeconds: elapsed)
        }
    }

    func recordClickSuppressorHandleEvent(startedAt: TimeInterval?) {
        guard let startedAt else { return }
        let elapsed = ProcessInfo.processInfo.systemUptime - startedAt
        updateState {
            clickSuppressorHandle.add(durationSeconds: elapsed)
        }
    }

    private func updateState(_ update: () -> Void) {
        guard Self.isEnabled else { return }
        let now = ProcessInfo.processInfo.systemUptime
        var snapshot: Snapshot?
        stateLock.lock()
        update()
        snapshot = snapshotIfNeeded(now: now)
        stateLock.unlock()
        if let snapshot {
            emit(snapshot: snapshot)
        }
    }

    private func snapshotIfNeeded(now: TimeInterval) -> Snapshot? {
        guard now >= nextEmitAt else { return nil }
        let windowSeconds = max(now - windowStart, 0.001)
        let snapshot = Snapshot(
            windowSeconds: windowSeconds,
            touchCallbacks: touchCallbacks,
            touchSamples: touchSamples,
            gestureCandidateEvaluations: gestureCandidateEvaluations,
            gestureTriggers: gestureTriggers,
            clickSuppressorInvocations: clickSuppressorInvocations,
            clickSuppressorEvents: clickSuppressorEvents,
            clickSuppressedEvents: clickSuppressedEvents,
            frontmostQueries: frontmostQueries,
            touchConversion: touchConversion,
            classifierProcess: classifierProcess,
            frontmostQuery: frontmostQuery,
            clickSuppressorHandle: clickSuppressorHandle
        )
        resetWindow(now: now)
        return snapshot
    }

    private func resetWindow(now: TimeInterval) {
        windowStart = now
        nextEmitAt = now + AppConstants.performanceMetricsLogIntervalSeconds
        touchCallbacks = 0
        touchSamples = 0
        gestureCandidateEvaluations = 0
        gestureTriggers = 0
        clickSuppressorInvocations = 0
        clickSuppressorEvents = 0
        clickSuppressedEvents = 0
        frontmostQueries = 0
        touchConversion = DurationStats()
        classifierProcess = DurationStats()
        frontmostQuery = DurationStats()
        clickSuppressorHandle = DurationStats()
    }

    private func emit(snapshot: Snapshot) {
        let callbackRate = Double(snapshot.touchCallbacks) / snapshot.windowSeconds
        let queryRate = Double(snapshot.frontmostQueries) / snapshot.windowSeconds
        let triggerRate = Double(snapshot.gestureTriggers) / snapshot.windowSeconds

        let message = String(
            format: """
            perf window=%.1fs touch_callbacks=%d(%.1f/s) touch_samples=%d candidate_evals=%d triggers=%d(%.2f/s) frontmost_queries=%d(%.1f/s) click_suppressor_invocations=%d click_events=%d dropped_click_events=%d touch_map_ms(avg=%.3f,max=%.3f) classify_ms(avg=%.3f,max=%.3f) frontmost_query_ms(avg=%.3f,max=%.3f) click_event_ms(avg=%.3f,max=%.3f)
            """,
            snapshot.windowSeconds,
            snapshot.touchCallbacks,
            callbackRate,
            snapshot.touchSamples,
            snapshot.gestureCandidateEvaluations,
            snapshot.gestureTriggers,
            triggerRate,
            snapshot.frontmostQueries,
            queryRate,
            snapshot.clickSuppressorInvocations,
            snapshot.clickSuppressorEvents,
            snapshot.clickSuppressedEvents,
            snapshot.touchConversion.averageMs,
            snapshot.touchConversion.maxMs,
            snapshot.classifierProcess.averageMs,
            snapshot.classifierProcess.maxMs,
            snapshot.frontmostQuery.averageMs,
            snapshot.frontmostQuery.maxMs,
            snapshot.clickSuppressorHandle.averageMs,
            snapshot.clickSuppressorHandle.maxMs
        )
        Log.info(Log.performance, message)
    }
}
