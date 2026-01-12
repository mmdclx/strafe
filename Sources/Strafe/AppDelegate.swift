import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let permissionService = AccessibilityPermissionService()
    private let frontmostQuery = FrontmostAppQuery()
    private let browserController = KeystrokeBrowserController()
    private lazy var eventRouter = GestureEventRouter(
        frontmostQuery: frontmostQuery,
        browserNavigator: browserController,
        permissionChecker: permissionService
    )
    private let gestureEngine = MultitouchGestureEngine()
    private var debugWindowController: DebugWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        permissionService.promptIfNeeded()

        gestureEngine.onGesture = { [weak self] event in
            self?.debugWindowController?.handle(event)
            self?.eventRouter.handle(event)
        }
        gestureEngine.onDebugState = { [weak self] state in
            guard let self else { return }
            let frontmost = self.frontmostQuery.frontmostBundleId()
            let trusted = self.permissionService.isTrusted()
            self.debugWindowController?.handle(debugState: state, frontmostBundleId: frontmost, isTrusted: trusted)
        }
        gestureEngine.start()

        Log.info(Log.app, "Strafe started")
    }

    func applicationWillTerminate(_ notification: Notification) {
        gestureEngine.stop()
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
            debugWindowController = DebugWindowController()
        }
        debugWindowController?.show()
    }
}
