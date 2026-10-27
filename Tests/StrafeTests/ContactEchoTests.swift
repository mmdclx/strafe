import AppKit
import MetalKit
import Testing
@testable import Strafe

@MainActor
struct ContactEchoTests {
    @Test func closingInspectorEliminatesRippleWorkAndReopensFresh() throws {
        guard ProcessInfo.processInfo.environment["STRAFE_ECHO_WINDOW_REVIEW"] == "1" else { return }
        _ = NSApplication.shared
        let permission = EchoPermissionProbe()
        let controller = DebugWindowController(permissionChecker: permission)
        let delivery = DebugStateDelivery()
        var streaming = false
        controller.onVisibilityChanged = { enabled in
            streaming = enabled
            if enabled { delivery.start { controller.handle(debugState: $0) } }
            else { delivery.stop() }
        }
        defer { controller.onVisibilityChanged = nil; delivery.stop(); controller.close() }
        func surface(in view: NSView?) -> ContactEchoSurfaceView? {
            guard let view else { return nil }
            if let found = view as? ContactEchoSurfaceView { return found }
            return view.subviews.lazy.compactMap { surface(in: $0) }.first
        }
        controller.show()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
        let original = try #require(surface(in: controller.window?.contentView))
        let metal = try #require(original.subviews.compactMap { $0 as? MTKView }.first)
        #expect(metal.isPaused)
        #expect(!metal.enableSetNeedsDisplay)
        #expect(streaming)

        // Another window's lifecycle must not wake this surface, even while Debug is open.
        let unrelated = NSWindow(contentRect: .zero, styleMask: [], backing: .buffered, defer: false)
        unrelated.isReleasedWhenClosed = false
        let beforeUnrelated = original.activity
        NotificationCenter.default.post(name: NSWindow.didChangeOcclusionStateNotification, object: unrelated)
        #expect(original.activity == beforeUnrelated)

        controller.handleRecognizedContact(CGPoint(x: 0.7, y: 0.5))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.12))
        #expect(original.isAnimating)
        #expect(original.activity.timerCallbacks > 0)
        #expect(original.activity.gpuSubmissions > 0)
        let pendingState = GestureDebugState(touches: [], restingId: nil, tapCandidateId: nil,
            tapCandidateDeltaX: nil, tapCandidateTravel: nil, restingTravel: nil,
            scrollSuppressed: false, lastTriggerAge: -1, tapLocked: false,
            tapCandidateAge: nil, restingMissingAge: nil)
        delivery.submit(pendingState)
        delivery.submit(pendingState) // Leave a coalesced callback queued at close.
        controller.close() // Close midway through a live ripple.
        #expect(!original.isAnimating)
        #expect(!streaming)
        #expect(metal.delegate == nil)
        #expect(surface(in: controller.window?.contentView) == nil)
        #expect(controller.model.contactEchoes.isEmpty)
        let closedActivity = original.activity
        let permissionReads = permission.reads

        for _ in 0..<100 {
            NotificationCenter.default.post(name: NSWindow.didChangeOcclusionStateNotification, object: unrelated)
            NotificationCenter.default.post(name: NSWindow.didChangeOcclusionStateNotification, object: controller.window)
            NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: NSApp)
            NotificationCenter.default.post(name: NSApplication.didUnhideNotification, object: NSApp)
            NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didActivateApplicationNotification, object: nil)
            controller.handleRecognizedContact(CGPoint(x: 0.3, y: 0.5))
            controller.handle(GestureRoutingOutcome(event: .left, disposition: .preview, bundleID: AppConstants.bundleId))
            delivery.submit(pendingState)
        }
        original.update(echoes: [ContactEcho(position: .zero, timestamp: ProcessInfo.processInfo.systemUptime)],
                        dark: true, reducedMotion: false, increasedContrast: false)
        original.draw(in: metal) // Late framework callbacks cannot submit another command either.
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 2.2))
        #expect(original.activity == closedActivity)
        #expect(permission.reads == permissionReads)
        #expect(controller.model.contactEchoes.isEmpty)
        #expect(controller.model.debugState == nil)
        #expect(!original.isAnimating)
        print("Closed inspector audit: 0 timer callbacks, 0 GPU submissions, 0 visibility callbacks, 0 permission refreshes over 2.2 seconds + 100 notification/input bursts.")

        controller.show()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.15))
        let reopened = try #require(surface(in: controller.window?.contentView))
        #expect(reopened !== original)
        #expect(!reopened.isAnimating)
        #expect(controller.model.contactEchoes.isEmpty)
        controller.handleRecognizedContact(CGPoint(x: 0.7, y: 0.5))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
        #expect(reopened.isAnimating)
        #expect(reopened.activity.gpuSubmissions > 0)
    }

    @Test func visibleWindowAnimationStopsAtIdleAndWhenHidden() throws {
        guard ProcessInfo.processInfo.environment["STRAFE_ECHO_WINDOW_REVIEW"] == "1" else { return }
        _ = NSApplication.shared
        let surface = ContactEchoSurfaceView()
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 280, height: 180),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = surface
        window.orderFrontRegardless()
        defer { surface.stop(); window.close() }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        #expect(window.occlusionState.contains(.visible))
        let now = ProcessInfo.processInfo.systemUptime
        surface.update(echoes: [ContactEcho(position: CGPoint(x: 0.7, y: 0.5), timestamp: now)], dark: true, reducedMotion: false, increasedContrast: false)
        #expect(surface.isAnimating)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.1))
        #expect(!surface.isAnimating)
        surface.update(echoes: [ContactEcho(position: CGPoint(x: 0.3, y: 0.5), timestamp: ProcessInfo.processInfo.systemUptime)], dark: false, reducedMotion: false, increasedContrast: false)
        #expect(surface.isAnimating)
        window.orderOut(nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        #expect(!surface.isAnimating)
        surface.update(echoes: [], dark: false, reducedMotion: false, increasedContrast: false)
        window.orderFrontRegardless()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        #expect(!surface.isAnimating)
    }

    @Test func lifetimeAndReducedMotionDoNotReplayOldEchoes() {
        let echo = ContactEcho(position: .zero, timestamp: 100)
        #expect(!echo.isActive(at: 99))
        #expect(echo.isActive(at: 100.99))
        #expect(!echo.isActive(at: 101))
        #expect(echo.isActive(at: 100.29, reducedMotion: true))
        #expect(!echo.isActive(at: 100.3, reducedMotion: true))
        #expect(echo.shaderAge(at: 100.01, reducedMotion: true) == echo.shaderAge(at: 100.25, reducedMotion: true))
    }

    @Test func contactCoordinatesShareTheTrackpadMapping() {
        let size = CGSize(width: 230, height: 146)
        #expect(InspectorTrackpadGeometry.point(CGPoint(x: 0, y: 1), in: size) == CGPoint(x: 24, y: 40))
        #expect(InspectorTrackpadGeometry.point(CGPoint(x: 1, y: 0), in: size) == CGPoint(x: 206, y: 88))
        #expect(InspectorTrackpadGeometry.point(CGPoint(x: 0.5, y: 0.5), in: size) == CGPoint(x: 115, y: 64))
    }

    /// Exercise actual Metal compilation and rendering; optional PNGs capture the GPU output.
    @Test func metalRendersAndSettlesInBothAppearances() throws {
        guard MTLCreateSystemDefaultDevice() != nil else { return }
        let renderer = try ContactEchoRenderer()
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 560, height: 360, mipmapped: false)
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = .shared
        let texture = try #require(renderer.device.makeTexture(descriptor: descriptor))
        let echo = ContactEcho(position: CGPoint(x: 0.65, y: 0.5), timestamp: 100)
        let size = CGSize(width: 280, height: 180)
        func render(_ echoes: [ContactEcho], _ now: TimeInterval, _ dark: Bool, reduced: Bool = false) throws -> [UInt8] {
            let command = try #require(renderer.render(to: texture, size: size, echoes: echoes, now: now, dark: dark, reducedMotion: reduced))
            command.waitUntilCompleted()
            #expect(command.status == .completed)
            #expect(command.error == nil)
            var pixels = [UInt8](repeating: 0, count: 560 * 360 * 4)
            texture.getBytes(&pixels, bytesPerRow: 560 * 4, from: MTLRegionMake2D(0, 0, 560, 360), mipmapLevel: 0)
            return pixels
        }
        for dark in [false, true] {
            let idle = try render([], 100, dark)
            for age in [0.08, 0.2, 0.4, 0.7] {
                let active = try render([echo], 100 + age, dark)
                #expect(active != idle)
                if let directory = ProcessInfo.processInfo.environment["STRAFE_ECHO_SNAPSHOTS"] {
                    try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
                    let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 560, pixelsHigh: 360,
                        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 560 * 4, bitsPerPixel: 32))
                    let data = try #require(bitmap.bitmapData)
                    for i in stride(from: 0, to: active.count, by: 4) {
                        data[i] = active[i+2]; data[i+1] = active[i+1]; data[i+2] = active[i]; data[i+3] = 255
                    }
                    try #require(bitmap.representation(using: .png, properties: [:])).write(to: URL(fileURLWithPath: directory).appendingPathComponent("echo-\(dark ? "dark" : "light")-\(Int(age * 1000)).png"))
                }
            }
            #expect(try render([echo], 101, dark) == idle)
            let reducedStart = try render([echo], 100.01, dark, reduced: true)
            #expect(reducedStart != idle)
            #expect(try render([echo], 100.25, dark, reduced: true) == reducedStart)
            #expect(try render([echo], 100.31, dark, reduced: true) == idle)
        }
    }
}

@MainActor
private final class EchoPermissionProbe: PermissionChecking {
    private(set) var reads = 0
    func isTrusted() -> Bool { reads += 1; return true }
    func promptIfNeeded() {}
}
