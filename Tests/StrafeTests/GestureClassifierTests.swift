import CoreGraphics
import Testing
@testable import Strafe

struct GestureClassifierTests {
    @Test(arguments: [CGFloat(0.3), CGFloat(0.7)])
    func tapFiresOnReleaseInCorrectDirection(tapX: CGFloat) {
        let gesture = GestureSequence()
        #expect(gesture.frame(10, [gesture.rest]) == nil)
        #expect(gesture.frame(10.1, [gesture.rest, gesture.tap(x: tapX)]) == nil)
        let event = gesture.frame(10.15, [gesture.rest])
        #expect(event == (tapX < 0.5 ? .left : .right))
        #expect(gesture.frame(10.16, [gesture.rest]) == nil)
    }

    @Test(arguments: [TouchPhase.breaking, .leaving])
    func endingPhaseFiresOnlyOnce(phase: TouchPhase) {
        let gesture = GestureSequence()
        gesture.frame(10, [gesture.rest])
        gesture.frame(10.1, [gesture.rest, gesture.tap()])
        #expect(gesture.frame(10.15, [gesture.rest, gesture.tap(phase: phase)]) == .right)
        #expect(gesture.frame(10.16, [gesture.rest, gesture.tap(phase: phase)]) == nil)
        #expect(gesture.frame(10.17, [gesture.rest]) == nil)
    }

    @Test func oneFingerNeverTriggers() {
        let gesture = GestureSequence()
        #expect(gesture.frame(10, [gesture.rest]) == nil)
        #expect(gesture.frame(10.1, [gesture.rest]) == nil)
        #expect(gesture.frame(10.2, []) == nil)
    }

    @Test func tapsTooCloseToRestDoNotTrigger() {
        let gesture = GestureSequence()
        gesture.frame(10, [gesture.rest])
        gesture.frame(10.1, [gesture.rest, gesture.tap(x: 0.51)])
        #expect(gesture.frame(10.15, [gesture.rest]) == nil)
    }

    @Test func simultaneousFingersDoNotCountAsRestAndTap() {
        let gesture = GestureSequence()
        gesture.frame(10, [gesture.rest, gesture.tap()])
        gesture.frame(10.02, [gesture.rest, gesture.tap(phase: .touching)])
        #expect(gesture.frame(10.1, [gesture.rest]) == nil)
    }

    @Test func immatureRestDoesNotAcceptTap() {
        let gesture = GestureSequence()
        gesture.frame(10, [gesture.rest])
        gesture.frame(10.02, [gesture.rest, gesture.tap()])
        #expect(gesture.frame(10.03, [gesture.rest]) == nil)
    }

    @Test func longHoldDoesNotTriggerAndNextTapCanRecover() {
        let gesture = GestureSequence()
        gesture.frame(10, [gesture.rest])
        gesture.frame(10.1, [gesture.rest, gesture.tap()])
        #expect(gesture.frame(10.6, [gesture.rest, gesture.tap(phase: .touching)]) == nil)
        #expect(gesture.frame(10.61, [gesture.rest]) == nil)
        gesture.frame(10.7, [gesture.rest, gesture.tap(id: 3)])
        #expect(gesture.frame(10.75, [gesture.rest]) == .right)
    }

    @Test func movingTapIsRejectedEvenIfItReturnsToStart() {
        let gesture = GestureSequence()
        gesture.frame(10, [gesture.rest])
        gesture.frame(10.1, [gesture.rest, gesture.tap()])
        gesture.frame(10.12, [gesture.rest, gesture.tap(x: 0.76, phase: .touching)])
        gesture.frame(10.13, [gesture.rest, gesture.tap(phase: .touching)])
        #expect(gesture.frame(10.15, [gesture.rest]) == nil)
    }

    @Test func movingRestInvalidatesTap() {
        let gesture = GestureSequence()
        gesture.frame(10, [gesture.rest])
        gesture.frame(10.1, [gesture.rest, gesture.tap()])
        let movedRest = TouchSample(id: 1, position: CGPoint(x: 0.57, y: 0.5), phase: .touching)
        #expect(gesture.frame(10.15, [movedRest]) == nil)
    }

    @Test func scrollingSuppressesNavigationAndLiftResetsGesture() {
        let gesture = GestureSequence()
        gesture.frame(10, [gesture.rest])
        gesture.frame(10.1, [gesture.rest, gesture.tap()])
        let movedRest = TouchSample(id: 1, position: CGPoint(x: 0.5, y: 0.6), phase: .touching)
        let movedTap = TouchSample(id: 2, position: CGPoint(x: 0.7, y: 0.6), phase: .touching)
        #expect(gesture.frame(10.12, [movedRest, movedTap]) == nil)
        #expect(gesture.frame(10.15, [movedRest]) == nil)
        gesture.frame(10.2, [])
        gesture.frame(11, [gesture.rest])
        gesture.frame(11.1, [gesture.rest, gesture.tap()])
        #expect(gesture.frame(11.15, [gesture.rest]) == .right)
    }

    @Test func losingRestDoesNotTrigger() {
        let gesture = GestureSequence()
        gesture.frame(10, [gesture.rest])
        gesture.frame(10.1, [gesture.rest, gesture.tap()])
        #expect(gesture.frame(10.12, [gesture.tap(phase: .touching)]) == nil)
        // Release the candidate while its sample is still present, so this
        // exercises the missing-rest guard rather than the empty-frame reset.
        #expect(gesture.frame(10.15, [gesture.tap(phase: .leaving)]) == nil)
        #expect(gesture.frame(10.16, []) == nil)
    }

    @Test func repeatedTapsRearmButCooldownRejectsTooFastRelease() {
        let gesture = GestureSequence()
        gesture.frame(10, [gesture.rest])
        gesture.frame(10.1, [gesture.rest, gesture.tap()])
        #expect(gesture.frame(10.15, [gesture.rest]) == .right)
        // Rearm is 20 ms; cooldown is 25 ms. This tap starts after rearm
        // but ends before cooldown, so only the cooldown guard can reject it.
        gesture.frame(10.171, [gesture.rest, gesture.tap(id: 3)])
        #expect(gesture.frame(10.173, [gesture.rest]) == nil)
        gesture.frame(10.21, [gesture.rest, gesture.tap(id: 4, x: 0.3)])
        #expect(gesture.frame(10.25, [gesture.rest]) == .left)
    }

    @Test func cooldownSurvivesAllFingersLifting() {
        let gesture = GestureSequence()
        gesture.frame(10, [gesture.rest])
        gesture.frame(10.1, [gesture.rest, gesture.tap()])
        #expect(gesture.frame(10.15, [gesture.rest]) == .right)
        gesture.frame(10.151, [])
        // Inspect the retained trigger time; a fresh resting finger cannot
        // mature inside the cooldown, so a second valid tap cannot probe it.
        let state = gesture.classifier.process(samples: [], now: 10.16, includeDebugState: true).1
        #expect(abs((state?.lastTriggerAge ?? -1) - 0.01) < 0.000001)
    }

    @Test func debugStreamingDoesNotChangeRecognition() {
        let enabled = GestureSequence(includeDebugState: true)
        let disabled = GestureSequence()
        for (time, touches) in [(10.0, [enabled.rest]),
                                (10.1, [enabled.rest, enabled.tap()]),
                                (10.15, [enabled.rest])] {
            #expect(enabled.frame(time, touches) == disabled.frame(time, touches))
        }
        #expect(disabled.classifier.process(samples: [], now: 11, includeDebugState: false).1 == nil)
    }
}

private final class GestureSequence {
    let classifier = GestureClassifier()
    let rest = TouchSample(id: 1, position: CGPoint(x: 0.5, y: 0.5), phase: .touching)
    let includeDebugState: Bool

    init(includeDebugState: Bool = false) {
        self.includeDebugState = includeDebugState
    }

    func tap(id: Int = 2, x: CGFloat = 0.7, phase: TouchPhase = .starting) -> TouchSample {
        TouchSample(id: id, position: CGPoint(x: x, y: 0.5), phase: phase)
    }

    @discardableResult
    func frame(_ now: Double, _ touches: [TouchSample]) -> GestureEvent? {
        classifier.process(samples: touches, now: now, includeDebugState: includeDebugState).0
    }
}
