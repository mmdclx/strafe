import AppKit
import SwiftUI
import Testing
@testable import Strafe

@MainActor
struct InspectorModelTests {
    private func context(_ model: InspectorModel, trusted: Bool = true, app: String? = "com.google.Chrome", now: TimeInterval = 100) {
        model.updateContext(trusted: trusted, bundleID: app, name: "Chrome", icon: nil, now: now)
    }

    private func state(candidate: Bool = false, scroll: Bool = false, movement: CGFloat = 0, missing: TimeInterval? = nil) -> GestureDebugState {
        GestureDebugState(touches: [TouchDebugInfo(id: 1, position: CGPoint(x: 0.4, y: 0.5), phase: .touching, movedBeyondRest: movement > 0.06, movedBeyondScroll: scroll, travel: movement)],
                          restingId: 1, tapCandidateId: candidate ? 2 : nil,
                          tapCandidateDeltaX: candidate ? 0.2 : nil, tapCandidateTravel: candidate ? 0.002 : nil,
                          restingTravel: movement, scrollSuppressed: scroll, lastTriggerAge: -1,
                          tapLocked: candidate, tapCandidateAge: candidate ? 0.08 : nil, restingMissingAge: missing)
    }

    @Test func permissionStateUpdatesWithoutTouchInput() {
        let model = InspectorModel()
        context(model, trusted: false)
        #expect(!model.isTrusted)
        #expect(model.debugState == nil)
        #expect(model.message.eyebrow == "Gesture preview")
        context(model, trusted: true, now: 101)
        #expect(model.isTrusted)
        #expect(model.message.title == "Rest a finger to begin")
        context(model, trusted: false, now: 102)
        #expect(!model.isTrusted)
    }

    @Test func liveStatePrecedenceAndReset() {
        let model = InspectorModel()
        context(model)
        model.update(state(), now: 100)
        #expect(model.message.title == "Ready to tap")
        model.update(state(candidate: true), now: 100.1)
        #expect(model.message.title == "Tap detected")
        model.update(state(candidate: true, scroll: true), now: 100.2)
        #expect(model.message.title == "Scrolling")
        model.update(state(missing: 0.05), now: 100.3)
        #expect(model.message.title == "Resting finger lifted")
        model.update(state(movement: 0.07), now: 100.4)
        #expect(model.message.title == "Rest a finger to begin")
        model.clearLiveInput()
        #expect(model.message.title == "Rest a finger to begin")
    }

    @Test func echoesAreBoundedAndClearedByScrollingOrClosing() {
        let model = InspectorModel()
        for i in 0..<5 { model.recordContact(CGPoint(x: CGFloat(i) / 5, y: 0.5), now: 100 + Double(i) * 0.05) }
        #expect(model.contactEchoes.count == 3)
        #expect(model.contactEchoes.first?.position.x == 0.4)
        model.recordContact(CGPoint(x: 0.7, y: 0.5), now: 102)
        #expect(model.contactEchoes.count == 1)
        model.update(state(scroll: true), now: 102.1)
        #expect(model.contactEchoes.isEmpty)
        model.recordContact(CGPoint(x: 0.3, y: 0.5), now: 103)
        model.clearLiveInput()
        #expect(model.contactEchoes.isEmpty)
    }

    @Test(arguments: [GestureRoutingOutcome.Disposition.preview, .accessibilityRequired, .unsupportedApp, .noFrontmostApp])
    func blockedAndPreviewOutcomesNeverBecomeSent(disposition: GestureRoutingOutcome.Disposition) {
        let model = InspectorModel()
        context(model, trusted: disposition != .accessibilityRequired)
        model.record(GestureRoutingOutcome(event: .right, disposition: disposition, bundleID: "com.google.Chrome"), appName: "Chrome", now: 100)
        #expect(!model.message.title.contains("shortcut sent"))
        #expect(!model.lastOutcomeLabel.contains(" sent"))
        context(model, trusted: true, now: 101)
        #expect(!model.message.title.contains("shortcut sent"))
    }

    @Test func successExpiresButHistoryKeepsItsOriginalDestination() {
        let model = InspectorModel()
        context(model)
        model.record(GestureRoutingOutcome(event: .left, disposition: .sent, bundleID: "com.google.Chrome"), appName: "Chrome", now: 100)
        #expect(model.message.title == "Left shortcut sent")
        context(model, now: 102)
        #expect(model.message.title == "Rest a finger to begin")
        #expect(model.lastOutcomeLabel == "Left sent · Chrome")
        #expect(model.ageLabel == "2s ago")
        context(model, app: "com.apple.TextEdit", now: 103)
        #expect(model.message.title == "App not supported")
        #expect(model.lastOutcomeLabel == "Left sent · Chrome")
    }

    @Test func revocationAndAppChangesImmediatelyOverrideRecentSuccess() {
        let model = InspectorModel()
        context(model)
        model.record(GestureRoutingOutcome(event: .right, disposition: .sent, bundleID: "com.google.Chrome"), appName: "Chrome", now: 100)
        context(model, trusted: false, now: 100.1)
        #expect(model.recentOutcome == nil)
        #expect(!model.message.title.contains("sent"))
        context(model, app: "com.apple.TextEdit", now: 100.2)
        #expect(model.recentOutcome == nil)
        #expect(model.message.title == "App not supported")
    }

    @Test func scrollingOverridesRecentOutputAndRapidRepeatsReplaceHistory() {
        let model = InspectorModel()
        context(model)
        model.record(GestureRoutingOutcome(event: .left, disposition: .sent, bundleID: "com.google.Chrome"), appName: "Chrome", now: 100)
        model.record(GestureRoutingOutcome(event: .right, disposition: .sent, bundleID: "com.google.Chrome"), appName: "Chrome", now: 100.03)
        #expect(model.message.title == "Right shortcut sent")
        model.update(state(scroll: true), now: 100.1)
        #expect(model.message.title == "Scrolling")
        #expect(model.lastOutcomeLabel == "Right sent · Chrome")
    }

    /// Opt-in native renders for visual review; never starts the gesture engine or sends keys.
    @Test func renderInspectorForReview() throws {
        guard let directory = ProcessInfo.processInfo.environment["STRAFE_INSPECTOR_SNAPSHOTS"] else { return }
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        for dark in [false, true] {
            for width in [340.0, 530.0] {
                for scenario in ["permission", "idle", "sent", "details"] {
                    let model = InspectorModel()
                    context(model, trusted: scenario != "permission")
                    if scenario == "sent" || scenario == "details" {
                        model.update(state(), now: 100)
                        model.record(GestureRoutingOutcome(event: .right, disposition: .sent, bundleID: "com.google.Chrome"), appName: "Chrome", now: 100)
                    }
                    model.detailsExpanded = scenario == "details"
                    let height = width < 440 ? 650.0 : scenario == "details" ? 500.0 : 460.0
                    let view = InspectorView(model: model, openSettings: {})
                        .environment(\.colorScheme, dark ? .dark : .light)
                        .frame(width: width, height: height)
                    _ = NSApplication.shared
                    let host = NSHostingView(rootView: view)
                    host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.borderless], backing: .buffered, defer: false)
                    window.isReleasedWhenClosed = false
                    window.contentView = host
                    host.frame = NSRect(x: 0, y: 0, width: width, height: height)
                    host.layoutSubtreeIfNeeded()
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
                    let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    let png = try #require(bitmap.representation(using: .png, properties: [:]))
                    try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(scenario)-\(Int(width))-\(dark ? "dark" : "light").png"))
                    window.close()
                }
            }
        }
    }
}
