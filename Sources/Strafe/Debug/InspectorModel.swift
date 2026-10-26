import AppKit
import SwiftUI

/// Presentation only: recognition and navigation decisions remain in their existing owners.
@MainActor
final class InspectorModel: ObservableObject {
    struct Outcome {
        let routing: GestureRoutingOutcome
        let appName: String
        let timestamp: TimeInterval
    }

    struct Message: Equatable {
        let eyebrow: String
        let title: String
        let detail: String
    }

    @Published private(set) var isTrusted = false
    @Published private(set) var bundleID: String?
    @Published private(set) var appName = "No active app"
    @Published private(set) var appIcon: NSImage?
    @Published private(set) var debugState: GestureDebugState?
    @Published private(set) var lastOutcome: Outcome?
    @Published private(set) var now: TimeInterval = 0
    @Published var detailsExpanded = false
    @Published var settingsError = false

    func updateContext(trusted: Bool, bundleID: String?, name: String, icon: NSImage?, now: TimeInterval) {
        if isTrusted != trusted { isTrusted = trusted }
        if self.bundleID != bundleID || appName != name {
            self.bundleID = bundleID
            appName = name
            appIcon = icon
        }
        if self.now != now { self.now = now }
        if trusted && settingsError { settingsError = false }
    }

    func update(_ state: GestureDebugState, now: TimeInterval) {
        debugState = state
        self.now = now
    }

    func record(_ routing: GestureRoutingOutcome, appName: String, now: TimeInterval) {
        lastOutcome = Outcome(routing: routing, appName: appName, timestamp: now)
        self.now = now
    }

    func clearLiveInput() { debugState = nil }

    var isSupportedApp: Bool { bundleID.map(AppConstants.supportedBrowsers.contains) ?? false }
    var isPreviewApp: Bool { bundleID == AppConstants.bundleId }
    var outcomeAge: TimeInterval { lastOutcome.map { max(0, now - $0.timestamp) } ?? 0 }

    var recentOutcome: Outcome? {
        guard debugState?.scrollSuppressed != true else { return nil }
        guard let lastOutcome, outcomeAge < 1.4 else { return nil }
        // Changing foreground app or revoking permission must not leave a stale success headline.
        guard lastOutcome.routing.bundleID == bundleID else { return nil }
        if !isTrusted && lastOutcome.routing.disposition == .sent { return nil }
        return lastOutcome
    }

    var message: Message {
        let eyebrow = isTrusted ? "Gesture state" : "Gesture preview"
        if debugState?.scrollSuppressed == true {
            return Message(eyebrow: eyebrow, title: "Scrolling", detail: "Tab gestures are ignored while your fingers move.")
        }
        if let outcome = recentOutcome {
            let direction = outcome.routing.event == .left ? "Left" : "Right"
            switch outcome.routing.disposition {
            case .sent:
                return Message(eyebrow: "Gesture output", title: "\(direction) shortcut sent", detail: "Sent to \(outcome.appName).")
            case .preview:
                return Message(eyebrow: "Gesture preview", title: "\(direction) gesture detected", detail: "Inspector is active. No shortcut sent.")
            case .accessibilityRequired:
                return Message(eyebrow: "Gesture preview", title: "\(direction) gesture detected", detail: "No shortcut sent.")
            case .unsupportedApp:
                return Message(eyebrow: "Routing status", title: "App not supported", detail: "Gesture recognized. No shortcut sent.")
            case .noFrontmostApp:
                return Message(eyebrow: "Routing status", title: "No active app", detail: "Gesture recognized. No shortcut sent.")
            }
        }
        if isTrusted && !isSupportedApp && !isPreviewApp {
            return Message(eyebrow: "Routing status", title: bundleID == nil ? "No active app" : "App not supported", detail: "Switch to Safari, Chrome, Finder, or Terminal.")
        }
        guard let state = debugState, !state.touches.isEmpty else {
            return Message(eyebrow: eyebrow, title: "Rest a finger to begin", detail: "Your next gesture will appear here.")
        }
        if state.tapCandidateId != nil {
            return Message(eyebrow: eyebrow, title: "Tap detected", detail: "Release the tapping finger to complete the gesture.")
        }
        if state.restingMissingAge != nil {
            return Message(eyebrow: eyebrow, title: "Resting finger lifted", detail: "Keep one finger resting as you tap.")
        }
        if state.restingTravel.map({ $0 > CGFloat(AppConstants.restingMovementThreshold) }) == true {
            return Message(eyebrow: eyebrow, title: "Rest a finger to begin", detail: "Lift and rest a finger to start again.")
        }
        if state.restingId != nil {
            return Message(eyebrow: eyebrow, title: "Ready to tap", detail: "Tap to either side of your resting finger.")
        }
        return Message(eyebrow: eyebrow, title: "Finding a resting finger", detail: "Keep one finger still on the trackpad.")
    }

    var contextLabel: String {
        if isPreviewApp { return "Preview only" }
        return isSupportedApp ? "Supported app" : "No shortcut sent"
    }

    var lastOutcomeLabel: String {
        guard let outcome = lastOutcome else { return "No gesture yet" }
        let direction = outcome.routing.event == .left ? "Left" : "Right"
        switch outcome.routing.disposition {
        case .sent: return "\(direction) sent · \(outcome.appName)"
        case .preview: return "\(direction) preview"
        case .accessibilityRequired: return "\(direction) blocked · Accessibility"
        case .unsupportedApp: return "\(direction) blocked · \(outcome.appName)"
        case .noFrontmostApp: return "\(direction) blocked · No app"
        }
    }

    var ageLabel: String {
        guard lastOutcome != nil else { return "" }
        if outcomeAge < 2 { return "just now" }
        if outcomeAge < 60 { return "\(Int(outcomeAge))s ago" }
        if outcomeAge < 3600 { return "\(Int(outcomeAge / 60))m ago" }
        return "\(Int(outcomeAge / 3600))h ago"
    }
}
