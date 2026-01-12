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
        guard permissionChecker.isTrusted() else {
            Log.debug(Log.permissions, "Gesture ignored - accessibility not trusted")
            return false
        }
        guard let bundleId = frontmostQuery.frontmostBundleId(),
              AppConstants.supportedBrowsers.contains(bundleId) else {
            return false
        }

        switch event {
        case .left:
            browserNavigator.navigateLeft()
        case .right:
            browserNavigator.navigateRight()
        }
        return true
    }
}
