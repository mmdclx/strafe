import Foundation
import CoreGraphics

final class ClickSuppressor {
    private let stateLock = NSLock()
    private var suppressUntil: TimeInterval = 0
    private var eventTap: CFMachPort?
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
        CGEvent.tapEnable(tap: tap, enable: true)

        stateLock.lock()
        eventTap = tap
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
        eventTap = nil
        runLoopSource = nil
        runLoop = nil
        tapThread = nil
        stateLock.unlock()

        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let loop, let source {
            CFRunLoopRemoveSource(loop, source, .commonModes)
            CFRunLoopStop(loop)
        }
    }

    func suppressClicks(for duration: TimeInterval) {
        let until = ProcessInfo.processInfo.systemUptime + duration
        stateLock.lock()
        suppressUntil = max(suppressUntil, until)
        stateLock.unlock()
    }

    private func shouldSuppress(now: TimeInterval) -> Bool {
        stateLock.lock()
        let suppress = now < suppressUntil
        stateLock.unlock()
        return suppress
    }

    private func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            stateLock.lock()
            let tap = eventTap
            stateLock.unlock()
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .leftMouseDown || type == .leftMouseUp || type == .leftMouseDragged {
            let now = ProcessInfo.processInfo.systemUptime
            if shouldSuppress(now: now) {
                return nil
            }
        }

        return Unmanaged.passUnretained(event)
    }
}
