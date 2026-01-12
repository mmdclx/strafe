import Foundation
import CoreGraphics

enum AppConstants {
    static let appName = "Strafe"
    static let bundleId = "com.mmdclx.Strafe"

    static let supportedBrowsers: Set<String> = [
        "com.google.Chrome",
        "com.apple.Safari",
        "com.apple.finder",
        "com.apple.Terminal"
    ]

    static let cooldownSeconds: TimeInterval = 0.05
    static let tapMaxDurationSeconds: TimeInterval = 0.45
    static let minTapDelta: Float = 0.02
    static let restingMovementThreshold: Float = 0.06
    static let scrollMovementThreshold: Float = 0.08
    static let restingGraceSeconds: TimeInterval = 0.12
    static let restingReacquireThreshold: CGFloat = 0.12
    static let tapReleaseGraceSeconds: TimeInterval = 0.12
    static let tapMinDelaySeconds: TimeInterval = 0.02
    static let restingMinAgeSeconds: TimeInterval = 0.10
    static let tapCandidateMaxTravel: Float = 0.04
    static let scrollSuppressionSeconds: TimeInterval = 0.20
}
