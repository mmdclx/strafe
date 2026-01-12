import Foundation
import CoreGraphics

enum AppConstants {
    static let appName = "TabTap"
    static let bundleId = "com.mmdclx.TabTap"

    static let supportedBrowsers: Set<String> = [
        "com.google.Chrome",
        "com.apple.Safari",
        "com.apple.finder",
        "com.apple.Terminal"
    ]

    static let cooldownSeconds: TimeInterval = 0.05
    static let tapMaxDurationSeconds: TimeInterval = 0.45
    static let minTapDelta: Float = 0.01
    static let restingMovementThreshold: Float = 0.06
    static let scrollMovementThreshold: Float = 0.12
    static let restingGraceSeconds: TimeInterval = 0.12
    static let restingReacquireThreshold: CGFloat = 0.12
    static let tapReleaseGraceSeconds: TimeInterval = 0.12
    static let tapMinDelaySeconds: TimeInterval = 0.02
}
