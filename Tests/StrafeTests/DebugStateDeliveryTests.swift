import Foundation
import Testing
@testable import Strafe

@MainActor
struct DebugStateDeliveryTests {
    private func state(_ touches: [TouchDebugInfo]) -> GestureDebugState {
        GestureDebugState(touches: touches, restingId: touches.first?.id, tapCandidateId: nil,
                          tapCandidateDeltaX: nil, tapCandidateTravel: nil, restingTravel: nil,
                          scrollSuppressed: false, lastTriggerAge: -1, tapLocked: false,
                          tapCandidateAge: nil, restingMissingAge: nil)
    }

    @Test func finalLiftArrivesEvenWhenTheInputStreamStops() async throws {
        let delivery = DebugStateDelivery()
        var counts: [Int] = []
        delivery.start { counts.append($0.touches.count) }
        let finger = TouchDebugInfo(id: 1, position: .zero, phase: .touching, movedBeyondRest: false, movedBeyondScroll: false, travel: 0)
        delivery.submit(state([finger]))
        delivery.submit(state([finger]))
        delivery.submit(state([]))
        #expect(counts == [1])
        try await Task.sleep(for: .milliseconds(100))
        #expect(counts == [1, 0])
        delivery.stop()
    }

    @Test func closingCancelsPendingFramesAndReopeningStartsFresh() async throws {
        let delivery = DebugStateDelivery()
        var count = 0
        delivery.start { _ in count += 1 }
        delivery.submit(state([]))
        delivery.submit(state([]))
        delivery.stop()
        delivery.submit(state([]))
        try await Task.sleep(for: .milliseconds(100))
        #expect(count == 1)
        delivery.start { _ in count += 1 }
        delivery.submit(state([]))
        #expect(count == 2)
        delivery.stop()
    }
}
