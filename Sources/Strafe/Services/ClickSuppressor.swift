import Foundation
import CoreGraphics

final class ClickSuppressor {
    private let stateLock = NSLock()
    private let disableQueue = DispatchQueue(label: "Strafe.ClickSuppressor.Disable")
    private var suppressUntil: TimeInterval = 0
    private var eventTap: CFMachPort?
    private var isTapEnabled = false
    private var scheduledDisable: DispatchWorkItem?
    private var scheduledDisableTarget: TimeInterval = 0
    private var runLoopSource: CFRunLoopSource?
    private var runLoop: CFRunLoop?
    private var tapThread: Thread?

    func start() {
        stateLock.lock()
        if eventTap != nil {
            stateLock.unlock()
            return
        }
        stateLock.unlock()

        let thread = Thread(target: self, selector: #selector(runEventTapThread), object: nil)

        thread.name = "Strafe.ClickSuppressor"
        thread.start()

        stateLock.lock()
        tapThread = thread
        stateLock.unlock()
    }

    @objc private func runEventTapThread() {
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let mask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.leftMouseUp.rawValue)
            | CGEventMask(1 << CGEventType.leftMouseDragged.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let suppressor = Unmanaged<ClickSuppressor>.fromOpaque(refcon).takeUnretainedValue()
            return suppressor.handleEvent(proxy: proxy, type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) else {
            Log.info(Log.app, "Click suppressor event tap failed to start")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        let currentRunLoop = CFRunLoopGetCurrent()
        CFRunLoopAddSource(currentRunLoop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: false)

        stateLock.lock()
        eventTap = tap
        isTapEnabled = false
        runLoopSource = source
        runLoop = currentRunLoop
        stateLock.unlock()

        CFRunLoopRun()
    }

    func stop() {
        stateLock.lock()
        let tap = eventTap
        let source = runLoopSource
        let loop = runLoop
        let scheduledDisable = scheduledDisable
        eventTap = nil
        isTapEnabled = false
        suppressUntil = 0
        self.scheduledDisable = nil
        scheduledDisableTarget = 0
        runLoopSource = nil
        runLoop = nil
        tapThread = nil
        stateLock.unlock()
        scheduledDisable?.cancel()

        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let loop, let source {
            CFRunLoopRemoveSource(loop, source, .commonModes)
            CFRunLoopStop(loop)
        }
    }

    func suppressClicks(for duration: TimeInterval) {
        PerformanceMetrics.shared.recordClickSuppressorInvocation()
        let now = ProcessInfo.processInfo.systemUptime
        let requestedUntil = now + duration
        var tapToEnable: CFMachPort?
        var targetUntil: TimeInterval = 0
        var disableWorkItem: DispatchWorkItem?
        stateLock.lock()
        suppressUntil = max(suppressUntil, requestedUntil)
        targetUntil = suppressUntil
        scheduledDisable?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.disableTapIfExpired(targetUntil: targetUntil)
        }
        scheduledDisable = workItem
        scheduledDisableTarget = targetUntil
        disableWorkItem = workItem
        if !isTapEnabled, let tap = eventTap {
            isTapEnabled = true
            tapToEnable = tap
        }
        stateLock.unlock()
        if let tapToEnable {
            CGEvent.tapEnable(tap: tapToEnable, enable: true)
        }
        if let disableWorkItem {
            let delay = max(targetUntil - now, 0)
            disableQueue.asyncAfter(deadline: .now() + delay, execute: disableWorkItem)
        }
    }

    private func disableTapIfExpired(targetUntil: TimeInterval) {
        var tapToDisable: CFMachPort?
        let now = ProcessInfo.processInfo.systemUptime
        stateLock.lock()
        guard scheduledDisableTarget == targetUntil else {
            stateLock.unlock()
            return
        }
        guard now >= suppressUntil else {
            stateLock.unlock()
            return
        }
        scheduledDisable = nil
        scheduledDisableTarget = 0
        if isTapEnabled {
            isTapEnabled = false
            tapToDisable = eventTap
        }
        stateLock.unlock()
        if let tapToDisable {
            CGEvent.tapEnable(tap: tapToDisable, enable: false)
        }
    }

    private func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        let startedAt = PerformanceMetrics.startTimestamp()
        defer {
            PerformanceMetrics.shared.recordClickSuppressorHandleEvent(startedAt: startedAt)
        }

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            var tapToEnable: CFMachPort?
            stateLock.lock()
            if isTapEnabled {
                tapToEnable = eventTap
            }
            stateLock.unlock()
            if let tapToEnable {
                CGEvent.tapEnable(tap: tapToEnable, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .leftMouseDown || type == .leftMouseUp || type == .leftMouseDragged {
            let now = ProcessInfo.processInfo.systemUptime
            var shouldSuppress = false
            stateLock.lock()
            shouldSuppress = now < suppressUntil
            stateLock.unlock()

            if shouldSuppress {
                PerformanceMetrics.shared.recordClickSuppressorEvent(suppressed: true)
                return nil
            }
            PerformanceMetrics.shared.recordClickSuppressorEvent(suppressed: false)
        }

        return Unmanaged.passUnretained(event)
    }
}
