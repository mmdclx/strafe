import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let permissionService = AccessibilityPermissionService()
    private let frontmostQuery = FrontmostAppQuery()
    private let browserController = KeystrokeBrowserController()
    private let clickSuppressor = ClickSuppressor()
    private lazy var eventRouter = GestureEventRouter(
        frontmostQuery: frontmostQuery,
        browserNavigator: browserController,
        permissionChecker: permissionService
    )
    private let gestureEngine = MultitouchGestureEngine()
    private var debugWindowController: DebugWindowController?
    private var statusItem: NSStatusItem?
    private let debugStateDelivery = DebugStateDelivery()
    private var handleDebugOutcome: ((GestureRoutingOutcome) -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        permissionService.promptIfNeeded()
        clickSuppressor.start()
        if PerformanceMetrics.isEnabled {
            Log.info(Log.performance, "Performance metrics enabled (window: \(AppConstants.performanceMetricsLogIntervalSeconds)s)")
        }

        gestureEngine.onGesture = { [weak self] event in
            guard let self else { return }
            let outcome = self.eventRouter.route(event)
            self.handleDebugOutcome?(outcome)
            if outcome.disposition == .sent {
                self.clickSuppressor.suppressClicks(for: AppConstants.clickSuppressionSeconds)
            }
        }
        setDebugStateStreaming(enabled: false)
        gestureEngine.start()

        Log.info(Log.app, "Strafe started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        gestureEngine.stop()
        clickSuppressor.stop()
        Log.info(Log.app, "Strafe stopped")
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = MenuBarIcon.makeImage()
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        let debugItem = NSMenuItem(title: "Debug", action: #selector(openDebug), keyEquivalent: "d")
        debugItem.target = self
        menu.addItem(debugItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Strafe", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        item.menu = menu

        statusItem = item
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    @objc private func openDebug() {
        if debugWindowController == nil {
            debugWindowController = DebugWindowController(permissionChecker: permissionService)
            debugWindowController?.onVisibilityChanged = { [weak self] isVisible in
                self?.setDebugStateStreaming(enabled: isVisible)
            }
        }
        debugWindowController?.show()
    }

    private func setDebugStateStreaming(enabled: Bool) {
        if !enabled {
            handleDebugOutcome = nil
            gestureEngine.onDebugState = nil
            debugStateDelivery.stop()
            return
        }
        handleDebugOutcome = { [weak self] outcome in
            self?.debugWindowController?.handle(outcome)
        }
        debugStateDelivery.start { [weak self] state in
            self?.debugWindowController?.handle(debugState: state)
        }
        gestureEngine.onDebugState = { [weak self] state in
            // Recognition is an event: preserve it before the 30 Hz live-frame coalescer.
            if let position = state.recognizedContact {
                self?.debugWindowController?.handleRecognizedContact(position)
            }
            self?.debugStateDelivery.submit(state)
        }
    }
}
