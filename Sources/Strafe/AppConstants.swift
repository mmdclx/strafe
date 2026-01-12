import Foundation
import CoreGraphics

enum AppConstants {
    static let appName = "Strafe" // Display name used in UI/logging.
    static let bundleId = "com.mmdclx.Strafe" // Bundle identifier for logging and permissions.

    static let supportedBrowsers: Set<String> = [
        "com.google.Chrome",
        "com.apple.Safari",
        "com.apple.finder",
        "com.apple.Terminal"
    ] // Allowlist of frontmost bundle IDs eligible for tab switching.

    static let cooldownSeconds: TimeInterval = 0.025 // Minimum time between triggered gestures.
    static let tapMaxDurationSeconds: TimeInterval = 0.45 // Max time a tap candidate can live before expiring.
    static let minTapDelta: Float = 0.02 // Minimum left/right separation between rest and tap.
    static let restingMovementThreshold: Float = 0.06 // Travel distance that disqualifies the resting finger.
    static let scrollMovementThreshold: Float = 0.08 // Travel distance that marks a touch as scrolling.
    static let restingGraceSeconds: TimeInterval = 0.12 // Grace period before dropping a missing resting touch.
    static let restingReacquireThreshold: CGFloat = 0.12 // Distance allowed to re-acquire a resting touch.
    static let tapReleaseGraceSeconds: TimeInterval = 0.06 // Debounce window after two-finger contact ends.
    static let tapMinDelaySeconds: TimeInterval = 0.01 // Minimum time between resting touch and tap candidate.
    static let restingMinAgeSeconds: TimeInterval = 0.05 // Required age of resting touch before accepting taps.
    static let tapCandidateMaxTravel: Float = 0.04 // Max tap finger travel allowed before canceling.
    static let scrollSuppressionSeconds: TimeInterval = 0.20 // Suppression window after scroll-like movement.
}
