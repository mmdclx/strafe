import Carbon
import CoreGraphics
import Testing
@testable import Strafe

@MainActor
struct NavigationTests {
    // Keep the product's expected allowlist explicit so accidental removals
    // cannot silently reduce the set of apps exercised by these tests.
    @Test(arguments: ["com.google.Chrome", "com.apple.Safari", "com.apple.finder", "com.apple.Terminal"])
    func supportedAppsProduceCorrectTabShortcuts(bundleID: String) {
        var events: [CGEvent] = []
        let navigator = KeystrokeBrowserController(postEvent: { events.append($0) })
        let router = GestureEventRouter(frontmostQuery: FrontmostStub(bundleID),
                                        browserNavigator: navigator,
                                        permissionChecker: PermissionStub(trusted: true))
        #expect(router.handle(.left))
        #expect(router.handle(.right))
        #expect(events.count == 4)
        #expect(events.map(\.type) == [.keyDown, .keyUp, .keyDown, .keyUp])
        #expect(events.allSatisfy { $0.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_Tab) })
        #expect(events.map(\.flags) == [[.maskControl, .maskShift], [.maskControl, .maskShift], .maskControl, .maskControl])
    }

    @Test(arguments: [nil, "org.mozilla.firefox", "com.apple.TextEdit", "com.mmdclx.Strafe"] as [String?])
    func unsupportedOrMissingFrontmostAppProducesNoKeys(bundleID: String?) {
        var events: [CGEvent] = []
        let router = GestureEventRouter(frontmostQuery: FrontmostStub(bundleID),
                                        browserNavigator: KeystrokeBrowserController(postEvent: { events.append($0) }),
                                        permissionChecker: PermissionStub(trusted: true))
        #expect(!router.handle(.left))
        #expect(!router.handle(.right))
        #expect(events.isEmpty)
    }

    @Test func permissionsAndFrontmostAppAreRecheckedForEveryGesture() {
        var events: [CGEvent] = []
        let permission = PermissionStub(trusted: false)
        let frontmost = FrontmostStub("com.apple.Safari")
        let router = GestureEventRouter(frontmostQuery: frontmost,
                                        browserNavigator: KeystrokeBrowserController(postEvent: { events.append($0) }),
                                        permissionChecker: permission)
        #expect(!router.handle(.right))
        #expect(events.isEmpty)
        permission.trusted = true
        #expect(router.handle(.right))
        #expect(events.count == 2)
        frontmost.bundleID = "com.apple.TextEdit"
        #expect(!router.handle(.left))
        #expect(events.count == 2)
        frontmost.bundleID = "com.apple.Safari"
        permission.trusted = false
        #expect(!router.handle(.left))
        #expect(events.count == 2)
    }
}

@MainActor
private final class PermissionStub: PermissionChecking {
    var trusted: Bool
    init(trusted: Bool) { self.trusted = trusted }
    func isTrusted() -> Bool { trusted }
    func promptIfNeeded() {}
}

@MainActor
private final class FrontmostStub: FrontmostAppQuerying {
    var bundleID: String?
    init(_ bundleID: String?) { self.bundleID = bundleID }
    func frontmostBundleId() -> String? { bundleID }
}
