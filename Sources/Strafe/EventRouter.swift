struct GestureRoutingOutcome {
    enum Disposition {
        case sent, preview, accessibilityRequired, unsupportedApp, noFrontmostApp
    }
    let event: GestureEvent
    let disposition: Disposition
    let bundleID: String?
}

@MainActor
final class GestureEventRouter {
    private let frontmostQuery: FrontmostAppQuerying
    private let browserNavigator: BrowserNavigating
    private let permissionChecker: PermissionChecking

    init(frontmostQuery: FrontmostAppQuerying, browserNavigator: BrowserNavigating, permissionChecker: PermissionChecking) {
        self.frontmostQuery = frontmostQuery
        self.browserNavigator = browserNavigator
        self.permissionChecker = permissionChecker
    }

    @discardableResult
    func handle(_ event: GestureEvent) -> Bool {
        route(event).disposition == .sent
    }

    func route(_ event: GestureEvent) -> GestureRoutingOutcome {
        guard permissionChecker.isTrusted() else {
            Log.debug(Log.permissions, "Gesture ignored - accessibility not trusted")
            return GestureRoutingOutcome(event: event, disposition: .accessibilityRequired, bundleID: frontmostQuery.frontmostBundleId())
        }
        guard let bundleId = frontmostQuery.frontmostBundleId() else {
            return GestureRoutingOutcome(event: event, disposition: .noFrontmostApp, bundleID: nil)
        }
        guard AppConstants.supportedBrowsers.contains(bundleId) else {
            return GestureRoutingOutcome(event: event, disposition: bundleId == AppConstants.bundleId ? .preview : .unsupportedApp, bundleID: bundleId)
        }

        switch event {
        case .left:
            browserNavigator.navigateLeft()
        case .right:
            browserNavigator.navigateRight()
        }
        return GestureRoutingOutcome(event: event, disposition: .sent, bundleID: bundleId)
    }
}
