import AppKit
import MetalKit
import SwiftUI

struct ContactEcho: Equatable {
    static let depth: Float = 0.75
    static let iridescence: Float = 0.3
    static let duration: TimeInterval = 1
    static let reducedDuration: TimeInterval = 0.3

    let position: CGPoint
    let timestamp: TimeInterval

    func isActive(at now: TimeInterval, reducedMotion: Bool = false) -> Bool {
        now >= timestamp && now < timestamp + (reducedMotion ? Self.reducedDuration : Self.duration)
    }

    func shaderAge(at now: TimeInterval, reducedMotion: Bool) -> Float {
        // The prototype settles at normalized 1.1; map that endpoint to exactly 1,000 ms.
        reducedMotion ? 0.22 : Float((now - timestamp) / Self.duration) * 1.1
    }
}

enum InspectorTrackpadGeometry {
    static func point(_ normalized: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: 24 + min(1, max(0, normalized.x)) * max(0, size.width - 48),
                // Leave room below the contact for its label and the preview caption.
                y: 40 + (1 - min(1, max(0, normalized.y))) * max(0, size.height - 98))
    }
}

struct ContactEchoSurface: NSViewRepresentable {
    let echoes: [ContactEcho]
    let dark: Bool
    let reducedMotion: Bool
    let increasedContrast: Bool

    func makeNSView(context: Context) -> ContactEchoSurfaceView { ContactEchoSurfaceView() }
    func updateNSView(_ view: ContactEchoSurfaceView, context: Context) {
        view.update(echoes: echoes, dark: dark, reducedMotion: reducedMotion, increasedContrast: increasedContrast)
    }
    static func dismantleNSView(_ view: ContactEchoSurfaceView, coordinator: ()) { view.stop() }
}

/// A clock runs only during a visible echo. Touch snapshots retain their existing 30 Hz delivery.
@MainActor
final class ContactEchoSurfaceView: NSView, MTKViewDelegate {
    private let renderer = ContactEchoRenderer.shared
    private var metalView: MTKView?
    private var timer: Timer?
    private var echoes: [ContactEcho] = []
    private var dark = false
    private var reducedMotion = false
    private var increasedContrast = false
    private var stopped = false
    struct Activity: Equatable {
        var timerCallbacks = 0
        var gpuSubmissions = 0
        var visibilityCallbacks = 0
    }
    private(set) var activity = Activity()
    var isAnimating: Bool { timer != nil }
    override var isFlipped: Bool { true }

    init() {
        super.init(frame: .zero)
        setAccessibilityElement(false)
        if let renderer {
            let view = MTKView(frame: bounds, device: renderer.device)
            view.colorPixelFormat = .bgra8Unorm
            view.isPaused = true
            view.enableSetNeedsDisplay = false
            view.delegate = self
            view.autoresizingMask = [.width, .height]
            addSubview(view)
            metalView = view
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(echoes: [ContactEcho], dark: Bool, reducedMotion: Bool, increasedContrast: Bool) {
        guard !stopped else { return }
        guard self.echoes != echoes || self.dark != dark || self.reducedMotion != reducedMotion || self.increasedContrast != increasedContrast else { return }
        self.echoes = echoes
        self.dark = dark
        self.reducedMotion = reducedMotion
        self.increasedContrast = increasedContrast
        tick()
    }

    private var visible: Bool {
        !stopped && window?.isVisible == true && window?.isMiniaturized == false &&
        window?.occlusionState.contains(.visible) == true && !NSApp.isHidden && !isHiddenOrHasHiddenAncestor
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        cancelTimer()
        NotificationCenter.default.removeObserver(self)
        guard !stopped, let window else { return }
        // Only this surface's window can wake it; unrelated windows must not redraw it.
        for name in [NSWindow.didChangeOcclusionStateNotification, NSWindow.didMiniaturizeNotification,
                     NSWindow.didDeminiaturizeNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(visibilityChanged), name: name, object: window)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(windowClosing), name: NSWindow.willCloseNotification, object: window)
        for name in [NSApplication.didHideNotification, NSApplication.didUnhideNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(visibilityChanged), name: name, object: NSApp)
        }
        tick()
    }
    override func layout() { super.layout(); if visible { redraw() } }
    @objc private func visibilityChanged() {
        guard !stopped else { return }
        activity.visibilityCallbacks += 1
        tick()
    }
    @objc private func windowClosing() { stop() }

    private func cancelTimer() { timer?.invalidate(); timer = nil }

    /// Terminal teardown. A reopened inspector gets a fresh surface, never a replayed timer.
    func stop() {
        stopped = true
        cancelTimer()
        echoes = []
        NotificationCenter.default.removeObserver(self)
        metalView?.delegate = nil
        metalView?.releaseDrawables()
    }

    private func tick() {
        cancelTimer()
        guard visible else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let active = echoes.filter { $0.isActive(at: now, reducedMotion: reducedMotion) }
        redraw()
        guard !active.isEmpty else { return }
        let delay = reducedMotion
            ? max(0.001, (active.first?.timestamp ?? now) + ContactEcho.reducedDuration - now)
            : 1.0 / 60.0
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.stopped else { return }
                self.activity.timerCallbacks += 1
                self.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func redraw() {
        if let metalView { metalView.draw() } else { needsDisplay = true }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    func draw(in view: MTKView) {
        guard visible, let drawable = view.currentDrawable, let renderer else { return }
        let command = renderer.render(to: drawable.texture, size: bounds.size, echoes: echoes,
                        now: ProcessInfo.processInfo.systemUptime, dark: dark,
                        reducedMotion: reducedMotion, increasedContrast: increasedContrast,
                        drawable: drawable)
        if command != nil { activity.gpuSubmissions += 1 }
    }

    // A simple circular echo remains available if Metal cannot initialize.
    override func draw(_ dirtyRect: NSRect) {
        guard !stopped, metalView == nil else { return }
        (dark ? NSColor(srgbRed: 38/255, green: 41/255, blue: 34/255, alpha: 1)
              : NSColor(srgbRed: 243/255, green: 244/255, blue: 239/255, alpha: 1)).setFill()
        bounds.fill()
        let now = ProcessInfo.processInfo.systemUptime
        for echo in echoes where echo.isActive(at: now, reducedMotion: reducedMotion) {
            let t = CGFloat(echo.shaderAge(at: now, reducedMotion: reducedMotion))
            let radius = 8 + 50 * (1 - exp(-4 * t))
            let point = InspectorTrackpadGeometry.point(echo.position, in: bounds.size)
            let ring = NSBezierPath(ovalIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
            let alpha = (increasedContrast ? 0.8 : 0.4) * max(0, 1 - t / 1.1)
            (dark ? NSColor.white : NSColor.black).withAlphaComponent(alpha).setStroke()
            ring.lineWidth = 1
            ring.stroke()
        }
    }
}

@MainActor
final class ContactEchoRenderer {
    static let shared = try? ContactEchoRenderer()
    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState

    struct Uniforms {
        var screen: SIMD4<Float>
        var material: SIMD4<Float>
        var first = SIMD4<Float>.zero
        var second = SIMD4<Float>.zero
        var third = SIMD4<Float>.zero
    }

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw NSError(domain: "ContactEcho", code: 1)
        }
        self.device = device
        self.queue = queue
        // Embedded source keeps the signed .app self-contained without a runtime resource path.
        let library = try device.makeLibrary(source: ContactEchoShader.source, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "echoVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "echoFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    @discardableResult
    func render(to texture: MTLTexture, size: CGSize, echoes: [ContactEcho], now: TimeInterval,
                dark: Bool, reducedMotion: Bool = false, increasedContrast: Bool = false,
                drawable: CAMetalDrawable? = nil) -> MTLCommandBuffer? {
        guard size.width > 0, size.height > 0, let command = queue.makeCommandBuffer() else { return nil }
        var uniforms = Uniforms(screen: SIMD4(Float(size.width), Float(size.height), Float(texture.width), Float(texture.height)),
                                material: SIMD4(dark ? 1 : 0, ContactEcho.depth, ContactEcho.iridescence, increasedContrast ? 1 : 0))
        let active = echoes.filter { $0.isActive(at: now, reducedMotion: reducedMotion) }.suffix(3)
        let packed = active.map { echo -> SIMD4<Float> in
            let p = InspectorTrackpadGeometry.point(echo.position, in: size)
            return SIMD4(Float(p.x), Float(p.y), echo.shaderAge(at: now, reducedMotion: reducedMotion), 1)
        }
        if packed.count > 0 { uniforms.first = packed[0] }
        if packed.count > 1 { uniforms.second = packed[1] }
        if packed.count > 2 { uniforms.third = packed[2] }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return nil }
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        if let drawable { command.present(drawable) }
        command.commit()
        return command
    }
}
