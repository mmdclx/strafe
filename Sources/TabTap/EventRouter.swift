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

    func handle(_ event: GestureEvent) {
        guard permissionChecker.isTrusted() else {
            Log.debug(Log.permissions, "Gesture ignored - accessibility not trusted")
            return
        }
        guard let bundleId = frontmostQuery.frontmostBundleId(),
              AppConstants.supportedBrowsers.contains(bundleId) else {
            return
        }

        switch event {
        case .left:
            browserNavigator.navigateLeft()
        case .right:
            browserNavigator.navigateRight()
        }
    }
}
