import AppKit
import SwiftUI

@MainActor
final class DebugWindowController: NSWindowController, NSWindowDelegate {
    let model = InspectorModel()
    private let permissionChecker: PermissionChecking
    private var refreshTimer: Timer?
    private var streaming = false
    private var cachedApp: NSRunningApplication?
    private var cachedIcon: NSImage?
    var onVisibilityChanged: ((Bool) -> Void)?

    init(permissionChecker: PermissionChecking) {
        self.permissionChecker = permissionChecker
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 530, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "Strafe / Inspector"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 340, height: 380)
        window.setFrameAutosaveName("FieldnoteInspector")
        super.init(window: window)
        let content = InspectorView(model: model, openSettings: { [weak self] in self?.openSettings() })
        let hosting = NSHostingView(rootView: content)
        hosting.sizingOptions = []
        window.contentView = hosting
        window.delegate = self
        window.center()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(contextDidChange), name: NSWorkspace.didActivateApplicationNotification, object: nil)
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.didHideNotification, NSApplication.didUnhideNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(contextDidChange), name: name, object: nil)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        refreshContext()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        updateVisibility()
    }

    func windowWillClose(_ notification: Notification) { setStreaming(false) }
    func windowDidMiniaturize(_ notification: Notification) { setStreaming(false) }
    func windowDidDeminiaturize(_ notification: Notification) { updateVisibility() }
    func windowDidBecomeKey(_ notification: Notification) { contextDidChange() }

    @objc private func contextDidChange() {
        updateVisibility()
        if streaming { refreshContext() }
    }

    private func updateVisibility() {
        setStreaming(window?.isVisible == true && window?.isMiniaturized == false && !NSApp.isHidden)
    }

    private func setStreaming(_ enabled: Bool) {
        guard streaming != enabled else { return }
        streaming = enabled
        refreshTimer?.invalidate()
        refreshTimer = nil
        model.clearLiveInput()
        onVisibilityChanged?(enabled)
        guard enabled else { return }
        refreshContext()
        // Permission changes and outcome age must update even when there are no touch callbacks.
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshContext() }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    private func refreshContext() {
        let app = NSWorkspace.shared.frontmostApplication
        if cachedApp?.processIdentifier != app?.processIdentifier {
            cachedApp = app
            cachedIcon = app?.icon
        }
        let wasTrusted = model.isTrusted
        model.updateContext(trusted: permissionChecker.isTrusted(), bundleID: app?.bundleIdentifier,
                            name: app?.localizedName ?? "No active app", icon: cachedIcon,
                            now: ProcessInfo.processInfo.systemUptime)
        if streaming && wasTrusted != model.isTrusted, let view = window?.contentView {
            NSAccessibility.post(element: view, notification: .announcementRequested,
                userInfo: [.announcement: model.isTrusted ? "Accessibility access granted." : "Strafe can’t switch tabs. Accessibility access is required.",
                           .priority: NSAccessibilityPriorityLevel.high.rawValue])
        }
    }

    func handle(_ outcome: GestureRoutingOutcome) {
        guard streaming else { return }
        refreshContext()
        let name = outcome.bundleID.flatMap { id in
            NSRunningApplication.runningApplications(withBundleIdentifier: id).first?.localizedName
        } ?? "Unknown app"
        model.record(outcome, appName: name, now: ProcessInfo.processInfo.systemUptime)
    }

    func handle(debugState: GestureDebugState) {
        guard streaming else { return }
        model.update(debugState, now: ProcessInfo.processInfo.systemUptime)
    }

    private func openSettings() {
        // Only opens the pane. Trust is rechecked on activation and by the visible-window timer.
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        model.settingsError = !NSWorkspace.shared.open(url)
    }
}
