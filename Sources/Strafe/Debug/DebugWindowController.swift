import AppKit

@MainActor
final class DebugWindowController: NSWindowController, NSWindowDelegate {
    private let flashView = DebugFlashView()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 240),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Debug"
        window.isReleasedWhenClosed = false
        window.contentView = flashView
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func handle(_ event: GestureEvent) {
        guard window?.isKeyWindow == true else { return }
        switch event {
        case .left:
            flashView.flashLeft()
        case .right:
            flashView.flashRight()
        }
    }

    func handle(debugState: GestureDebugState, frontmostBundleId: String?, isTrusted: Bool) {
        guard window?.isVisible == true else { return }
        flashView.updateStatus(frontmostBundleId: frontmostBundleId, isTrusted: isTrusted)
        flashView.updateDebugState(debugState)
    }
}

private final class DebugFlashView: NSView {
    private let leftOverlay = NSView()
    private let rightOverlay = NSView()
    private let gestureOverlay = DebugGestureOverlayView()
    private let coordsLabel = NSTextField(labelWithString: "Callbacks: 0 | Touches: 0")
    private var callbackCount: Int = 0
    private var frontmostBundleId: String?
    private var isTrusted: Bool?
    private var lastState: GestureDebugState?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        configureOverlay(leftOverlay, color: NSColor.systemBlue.withAlphaComponent(0.55))
        configureOverlay(rightOverlay, color: NSColor.systemRed.withAlphaComponent(0.55))

        gestureOverlay.wantsLayer = true
        addSubview(gestureOverlay)

        coordsLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        coordsLabel.textColor = NSColor.secondaryLabelColor
        coordsLabel.lineBreakMode = .byWordWrapping
        coordsLabel.usesSingleLineMode = false
        coordsLabel.maximumNumberOfLines = 0
        coordsLabel.alignment = .left
        addSubview(coordsLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let halfWidth = bounds.width / 2
        leftOverlay.frame = NSRect(x: 0, y: 0, width: halfWidth, height: bounds.height)
        rightOverlay.frame = NSRect(x: halfWidth, y: 0, width: bounds.width - halfWidth, height: bounds.height)
        gestureOverlay.frame = bounds
        let labelHeight = min(bounds.height * 0.3, 120)
        coordsLabel.frame = NSRect(x: 12, y: 8, width: bounds.width - 24, height: labelHeight)
    }

    func flashLeft() {
        flash(view: leftOverlay)
    }

    func flashRight() {
        flash(view: rightOverlay)
    }

    func updateDebugState(_ state: GestureDebugState) {
        gestureOverlay.debugState = state
        lastState = state
        callbackCount += 1
        coordsLabel.stringValue = formatCoords(state)
    }

    func updateStatus(frontmostBundleId: String?, isTrusted: Bool) {
        self.frontmostBundleId = frontmostBundleId
        self.isTrusted = isTrusted
        if let state = lastState {
            coordsLabel.stringValue = formatCoords(state)
        }
    }

    private func configureOverlay(_ view: NSView, color: NSColor) {
        view.wantsLayer = true
        view.layer?.backgroundColor = color.cgColor
        view.alphaValue = 0
        addSubview(view)
    }

    private func flash(view: NSView) {
        view.alphaValue = 1
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 1.0
            view.animator().alphaValue = 0
        }
    }

    private func formatCoords(_ state: GestureDebugState) -> String {
        let resting = state.restingId.map(String.init) ?? "-"
        let candidate = state.tapCandidateId.map(String.init) ?? "-"
        let delta = state.tapCandidateDeltaX.map { String(format: "%.3f", $0) } ?? "-"
        let restingTravel = state.restingTravel.map { String(format: "%.3f", $0) } ?? "-"
        let candidateTravel = state.tapCandidateTravel.map { String(format: "%.3f", $0) } ?? "-"
        let suppressed = state.scrollSuppressed ? "yes" : "no"
        let lastAge = state.lastTriggerAge >= 0 ? String(format: "%.2fs", state.lastTriggerAge) : "-"
        let locked = state.tapLocked ? "yes" : "no"
        let candidateAge = state.tapCandidateAge.map { String(format: "%.2fs", $0) } ?? "-"
        let missingAge = state.restingMissingAge.map { String(format: "%.2fs", $0) } ?? "-"
        let trusted = isTrusted.map { $0 ? "yes" : "no" } ?? "-"
        let frontmost = frontmostBundleId ?? "-"
        let counts = "Callbacks: \(callbackCount) | Touches: \(state.touches.count)"
        let context = "Trusted: \(trusted) | Front: \(frontmost)"
        let summary = "Resting: \(resting) | Tap: \(candidate) | dX: \(delta) | rMv: \(restingTravel) | cMv: \(candidateTravel) | Locked: \(locked)"
        let timing = "Cand: \(candidateAge) | Missing: \(missingAge) | Suppressed: \(suppressed) | Last: \(lastAge)"
        let phases = state.touches
            .map { "\($0.id):\($0.phase.rawValue.prefix(3))" }
            .joined(separator: " ")
        return "\(counts)\n\(context)\n\(summary)\n\(timing)\n\(phases)"
    }
}

private final class DebugGestureOverlayView: NSView {
    var debugState: GestureDebugState? {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let state = debugState else { return }

        let restingPos = state.restingId.flatMap { id in
            state.touches.first(where: { $0.id == id })?.position
        }
        let candidatePos = state.tapCandidateId.flatMap { id in
            state.touches.first(where: { $0.id == id })?.position
        }

        if let restingPos {
            let x = restingPos.x * bounds.width
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x, y: 0))
            path.line(to: NSPoint(x: x, y: bounds.height))
            NSColor.tertiaryLabelColor.setStroke()
            path.lineWidth = 1
            path.stroke()
        }

        if let restingPos, let candidatePos, let delta = state.tapCandidateDeltaX {
            let start = point(restingPos)
            let end = point(candidatePos)
            let path = NSBezierPath()
            path.move(to: start)
            path.line(to: end)
            (delta < 0 ? NSColor.systemBlue : NSColor.systemRed).setStroke()
            path.lineWidth = 2
            path.stroke()
        }

        for touch in state.touches {
            let p = point(touch.position)
            let baseRadius: CGFloat = 5
            let rect = NSRect(x: p.x - baseRadius, y: p.y - baseRadius, width: baseRadius * 2, height: baseRadius * 2)
            NSColor.systemGreen.setFill()
            NSBezierPath(ovalIn: rect).fill()

            if touch.id == state.restingId {
                let ringRadius: CGFloat = 9
                let ringRect = NSRect(x: p.x - ringRadius, y: p.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2)
                NSColor.systemYellow.setStroke()
                let ring = NSBezierPath(ovalIn: ringRect)
                ring.lineWidth = 2
                ring.stroke()
            }

            if touch.id == state.tapCandidateId {
                let ringRadius: CGFloat = 8
                let ringRect = NSRect(x: p.x - ringRadius, y: p.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2)
                NSColor.systemOrange.setFill()
                NSBezierPath(ovalIn: ringRect).fill()
            }

            if touch.movedBeyondScroll {
                let ringRadius: CGFloat = 12
                let ringRect = NSRect(x: p.x - ringRadius, y: p.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2)
                NSColor.systemRed.setStroke()
                let ring = NSBezierPath(ovalIn: ringRect)
                ring.lineWidth = 1
                ring.stroke()
            }
        }
    }

    private func point(_ position: CGPoint) -> NSPoint {
        NSPoint(x: position.x * bounds.width, y: position.y * bounds.height)
    }
}
