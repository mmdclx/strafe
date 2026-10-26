import Testing
@testable import Strafe

struct ClickSuppressionWindowTests {
    @Test func suppressesOnlyBetweenTriggerAndDeadline() {
        var window = ClickSuppressionWindow()
        #expect(!window.isSuppressing(at: 10))
        let deadline = window.extend(for: AppConstants.clickSuppressionSeconds, now: 10)
        #expect(abs(deadline - 10.12) < 0.000001)
        #expect(window.isSuppressing(at: 10))
        #expect(window.isSuppressing(at: deadline - 0.001))
        #expect(!window.isSuppressing(at: deadline))
        #expect(!window.isSuppressing(at: deadline + 1))
        let earlyExpiry = window.expire(for: deadline, now: deadline - 0.001)
        #expect(!earlyExpiry)
        #expect(window.isSuppressing(at: deadline - 0.001))
        let expiry = window.expire(for: deadline, now: deadline)
        #expect(expiry)
        let duplicateExpiry = window.expire(for: deadline, now: deadline + 1)
        #expect(!duplicateExpiry)
    }

    @Test func repeatedTriggerExtendsWindowAndRejectsStaleTimer() {
        var window = ClickSuppressionWindow()
        let oldDeadline = window.extend(for: 0.12, now: 10)
        let newDeadline = window.extend(for: 0.12, now: 10.1)
        #expect(newDeadline > oldDeadline)
        #expect(window.isSuppressing(at: oldDeadline))
        let staleExpiry = window.expire(for: oldDeadline, now: oldDeadline)
        #expect(!staleExpiry)
        #expect(window.isSuppressing(at: oldDeadline))
        // A canceled work item may already be executing when the window changes.
        let delayedStaleExpiry = window.expire(for: oldDeadline, now: newDeadline + 1)
        #expect(!delayedStaleExpiry)
        let expiry = window.expire(for: newDeadline, now: newDeadline + 1)
        #expect(expiry)
        #expect(!window.isSuppressing(at: newDeadline + 1))
    }

    @Test func shorterRequestDoesNotShortenExistingWindow() {
        var window = ClickSuppressionWindow()
        let deadline = window.extend(for: 0.12, now: 10)
        let unchangedDeadline = window.extend(for: 0.01, now: 10.02)
        #expect(unchangedDeadline == deadline)
        #expect(window.isSuppressing(at: 10.1))
    }

    @Test func delayedTimerCannotCauseExtraSuppression() {
        var window = ClickSuppressionWindow()
        let deadline = window.extend(for: 0.12, now: 10)
        // No expiry callback is needed for mouse events to pass after the deadline.
        #expect(!window.isSuppressing(at: deadline + 0.5))
        let delayedExpiry = window.expire(for: deadline, now: deadline + 0.5)
        #expect(delayedExpiry)
        _ = window.extend(for: 0.12, now: 11)
        #expect(window.isSuppressing(at: 11))
        let staleExpiry = window.expire(for: deadline, now: 11)
        #expect(!staleExpiry)
    }

    @Test func stoppingClearsSuppressionAndInvalidatesPendingTimer() {
        var window = ClickSuppressionWindow()
        let deadline = window.extend(for: 0.12, now: 10)
        window.reset()
        #expect(!window.isSuppressing(at: 10.01))
        let stoppedExpiry = window.expire(for: deadline, now: deadline)
        #expect(!stoppedExpiry)
        let restartedDeadline = window.extend(for: 0.12, now: 20)
        #expect(window.isSuppressing(at: 20))
        let restartedExpiry = window.expire(for: restartedDeadline, now: restartedDeadline)
        #expect(restartedExpiry)
    }
}
