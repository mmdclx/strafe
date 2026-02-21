import AppKit

final class FrontmostAppQuery: FrontmostAppQuerying {
    func frontmostBundleId() -> String? {
        let startedAt = PerformanceMetrics.startTimestamp()
        let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        PerformanceMetrics.shared.recordFrontmostQuery(startedAt: startedAt)
        return bundleId
    }
}
