import Foundation
import CoreGraphics

enum TouchPhase: String {
    case starting
    case making
    case touching
    case breaking
    case lingering
    case leaving
    case hovering

    var isBeginning: Bool {
        self == .starting || self == .making
    }

    var isEnding: Bool {
        self == .breaking || self == .leaving
    }

    var isStable: Bool {
        self == .touching || self == .lingering
    }
}

struct TouchSample {
    let id: Int
    let position: CGPoint
    let phase: TouchPhase
}

struct TouchDebugInfo {
    let id: Int
    let position: CGPoint
    let phase: TouchPhase
    let movedBeyondRest: Bool
    let movedBeyondScroll: Bool
}

struct GestureDebugState {
    let touches: [TouchDebugInfo]
    let restingId: Int?
    let tapCandidateId: Int?
    let tapCandidateDeltaX: Float?
    let scrollSuppressed: Bool
    let lastTriggerAge: TimeInterval
    let tapLocked: Bool
    let tapCandidateAge: TimeInterval?
    let restingMissingAge: TimeInterval?
}

final class GestureClassifier {
    private struct TouchInfo {
        let id: Int
        var position: CGPoint
        let downTime: TimeInterval
        var lastUpdate: TimeInterval
        var phase: TouchPhase
        var lastPhase: TouchPhase?
        var movedBeyondRest: Bool
        var movedBeyondScroll: Bool
    }

    private struct TapCandidate {
        let id: Int
        let deltaX: Float
        let downTime: TimeInterval
    }

    private var activeTouches: [Int: TouchInfo] = [:]
    private var restingTouchId: Int?
    private var restingPosition: CGPoint?
    private var restingDownTime: TimeInterval?
    private var tapCandidate: TapCandidate?
    private var scrollSuppressed = false
    private var lastTriggerTime: TimeInterval = 0
    private var tapLocked = false
    private var restingMissingSince: TimeInterval?
    private var lastTwoTouchTime: TimeInterval?

    func process(samples: [TouchSample], now: TimeInterval) -> (GestureEvent?, GestureDebugState) {
        if samples.isEmpty {
            resetState()
            return (nil, debugState(now: now))
        }

        let previousIds = Set(activeTouches.keys)
        let currentIds = Set(samples.map { $0.id })
        let newIds = currentIds.subtracting(previousIds)
        let endedIds = previousIds.subtracting(currentIds)

        for sample in samples {
            if var info = activeTouches[sample.id] {
                let dx = Float(sample.position.x - info.position.x)
                let dy = Float(sample.position.y - info.position.y)
                let distance = hypotf(dx, dy)

                if distance > AppConstants.restingMovementThreshold {
                    info.movedBeyondRest = true
                }
                if distance > AppConstants.scrollMovementThreshold {
                    info.movedBeyondScroll = true
                }

                info.position = sample.position
                info.lastUpdate = now
                info.lastPhase = info.phase
                info.phase = sample.phase
                activeTouches[sample.id] = info
            } else {
                activeTouches[sample.id] = TouchInfo(
                    id: sample.id,
                    position: sample.position,
                    downTime: now,
                    lastUpdate: now,
                    phase: sample.phase,
                    lastPhase: nil,
                    movedBeyondRest: false,
                    movedBeyondScroll: false
                )
            }
        }

        if currentIds.count >= 2 {
            lastTwoTouchTime = now
        }

        if currentIds.count >= 2 {
            let movingTouches = activeTouches.values.filter { $0.movedBeyondScroll }.count
            if movingTouches >= 2 {
                scrollSuppressed = true
                tapCandidate = nil
            }
        } else {
            scrollSuppressed = false
        }

        if currentIds.count <= 1 {
            if let lastTwoTouchTime, now - lastTwoTouchTime < AppConstants.tapReleaseGraceSeconds {
                // Keep tapLocked briefly to avoid retriggers when touches jitter.
            } else {
                tapLocked = false
            }
        }

        if restingTouchId == nil {
            if let stable = activeTouches.values
                .filter({ $0.phase.isStable })
                .min(by: { $0.downTime < $1.downTime }) {
                restingTouchId = stable.id
                restingPosition = stable.position
                restingDownTime = stable.downTime
            } else if let earliest = activeTouches.values.min(by: { $0.downTime < $1.downTime }) {
                restingTouchId = earliest.id
                restingPosition = earliest.position
                restingDownTime = earliest.downTime
            }
        }

        if let restingId = restingTouchId, !currentIds.contains(restingId) {
            if let restingPosition,
               let closest = closestTouch(to: restingPosition),
               distance(closest.position, restingPosition) <= AppConstants.restingReacquireThreshold {
                restingTouchId = closest.id
                restingDownTime = closest.downTime
                self.restingPosition = closest.position
                restingMissingSince = nil
            } else {
                if restingMissingSince == nil {
                    restingMissingSince = now
                }
                if let missingSince = restingMissingSince,
                   now - missingSince > AppConstants.restingGraceSeconds {
                    restingTouchId = nil
                    restingDownTime = nil
                    restingPosition = nil
                    tapCandidate = nil
                    tapLocked = false
                    restingMissingSince = nil
                }
            }
        } else if let restingId = restingTouchId, let restingInfo = activeTouches[restingId] {
            restingMissingSince = nil
            restingPosition = restingInfo.position
            restingDownTime = restingInfo.downTime
        }

        var triggeredEvent: GestureEvent?

        if let candidate = tapCandidate {
            let candidateEnded = endedIds.contains(candidate.id)
            let candidatePhaseEnding = activeTouches[candidate.id]?.phase.isEnding == true
            if candidateEnded || candidatePhaseEnding {
                if shouldTriggerTap(candidate: candidate, now: now, currentIds: currentIds) {
                    triggeredEvent = candidate.deltaX < 0 ? .left : .right
                    lastTriggerTime = now
                    tapLocked = true
                }
                tapCandidate = nil
            }
        }

        for endedId in endedIds {
            activeTouches.removeValue(forKey: endedId)
        }

        if let restingId = restingTouchId,
           let restingInfo = activeTouches[restingId],
           !scrollSuppressed,
           tapCandidate == nil,
           !tapLocked,
           !restingInfo.movedBeyondRest {
            if let candidateInfo = selectCandidate(restingId: restingId, newIds: newIds) {
                let deltaX = Float(candidateInfo.position.x - restingInfo.position.x)
                tapCandidate = TapCandidate(id: candidateInfo.id, deltaX: deltaX, downTime: candidateInfo.downTime)
                tapLocked = true
            }
        }

        if let candidate = tapCandidate,
           let candidateInfo = activeTouches[candidate.id],
           candidateInfo.movedBeyondScroll {
            tapCandidate = nil
        }

        if let candidate = tapCandidate,
           now - candidate.downTime > AppConstants.tapMaxDurationSeconds {
            tapCandidate = nil
        }

        return (triggeredEvent, debugState(now: now))
    }

    private func selectCandidate(restingId: Int, newIds: Set<Int>) -> TouchInfo? {
        if let newCandidate = newIds
            .filter({ $0 != restingId })
            .compactMap({ activeTouches[$0] })
            .sorted(by: { $0.downTime > $1.downTime })
            .first {
            if let restingDownTime {
                let minDownTime = restingDownTime + AppConstants.tapMinDelaySeconds
                if newCandidate.downTime < minDownTime {
                    return nil
                }
            }
            return newCandidate
        }

        return activeTouches.values
            .filter { $0.id != restingId && $0.phase.isBeginning }
            .sorted(by: { $0.downTime > $1.downTime })
            .first
    }

    private func shouldTriggerTap(candidate: TapCandidate, now: TimeInterval, currentIds: Set<Int>) -> Bool {
        guard now - lastTriggerTime >= AppConstants.cooldownSeconds else { return false }
        guard now - candidate.downTime <= AppConstants.tapMaxDurationSeconds else { return false }
        guard abs(candidate.deltaX) >= AppConstants.minTapDelta else { return false }
        guard !scrollSuppressed else { return false }

        if let restingId = restingTouchId {
            guard currentIds.contains(restingId) else { return false }
            if let restingInfo = activeTouches[restingId], restingInfo.movedBeyondRest {
                return false
            }
        } else {
            return false
        }

        return true
    }

    private func resetState() {
        activeTouches.removeAll()
        restingTouchId = nil
        restingDownTime = nil
        restingPosition = nil
        tapCandidate = nil
        scrollSuppressed = false
        tapLocked = false
        restingMissingSince = nil
        lastTwoTouchTime = nil
    }

    private func debugState(now: TimeInterval) -> GestureDebugState {
        let touches = activeTouches.values.map { info in
            TouchDebugInfo(
                id: info.id,
                position: info.position,
                phase: info.phase,
                movedBeyondRest: info.movedBeyondRest,
                movedBeyondScroll: info.movedBeyondScroll
            )
        }
        let lastTriggerAge = lastTriggerTime > 0 ? now - lastTriggerTime : -1
        let tapCandidateAge = tapCandidate.map { now - $0.downTime }
        let restingMissingAge = restingMissingSince.map { now - $0 }
        return GestureDebugState(
            touches: touches,
            restingId: restingTouchId,
            tapCandidateId: tapCandidate?.id,
            tapCandidateDeltaX: tapCandidate?.deltaX,
            scrollSuppressed: scrollSuppressed,
            lastTriggerAge: lastTriggerAge,
            tapLocked: tapLocked,
            tapCandidateAge: tapCandidateAge,
            restingMissingAge: restingMissingAge
        )
    }

    private func closestTouch(to position: CGPoint) -> TouchInfo? {
        activeTouches.values.min(by: { distance($0.position, position) < distance($1.position, position) })
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
