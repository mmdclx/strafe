import Foundation

enum GestureEvent {
    case left
    case right
}

@MainActor
protocol GestureDetecting: AnyObject {
    var onGesture: ((GestureEvent) -> Void)? { get set }
    func start()
    func stop()
}

@MainActor
protocol BrowserNavigating: AnyObject {
    func navigateLeft()
    func navigateRight()
}

@MainActor
protocol PermissionChecking: AnyObject {
    func isTrusted() -> Bool
    func promptIfNeeded()
}

@MainActor
protocol FrontmostAppQuerying: AnyObject {
    func frontmostBundleId() -> String?
}
