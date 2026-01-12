import AppKit

final class FrontmostAppQuery: FrontmostAppQuerying {
    func frontmostBundleId() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}
