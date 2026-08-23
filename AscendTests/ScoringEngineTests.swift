import XCTest
@testable import Ascend

final class ScoringEngineTests: XCTestCase {
    private let engine = ScoringEngine()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testCompositeUsesApprovedWeights() {
        let vector = MasteryVector(exposure: 10, understanding: 20, practice: 30, retention: 40, autonomy: 50)
        XCTAssertEqual(vector.composite, 31.5, accuracy: 0.0001)
    }

    func testIndependentSolveRaisesAutonomyAndAwardsXP() {
        let input = ScoringInput(
            current: .zero,
            kind: .independentSolve,
            difficulty: 1,
            independence: 1,
            confidence: 1,
            stabilityDays: 3,
            lastEvidenceAt: nil,
            timestamp: now
        )

        let result = engine.apply(input)
        XCTAssertEqual(result.updated.autonomy, 12, accuracy: 0.0001)
        XCTAssertGreaterThan(result.updated.composite, 0)
        XCTAssertGreaterThan(result.xpAwarded, 0)
        XCTAssertGreaterThan(result.stabilityDays, 3)
    }

    func testDiminishingReturnsAndPerDimensionCap() {
        let low = engine.apply(input(current: .zero, kind: .project))
        let highVector = MasteryVector(exposure: 95, understanding: 95, practice: 95, retention: 95, autonomy: 95)
        let high = engine.apply(input(current: highVector, kind: .project))

        XCTAssertLessThan(high.updated.practice - 95, low.updated.practice)
        XCTAssertLessThanOrEqual(low.updated.practice, 12)
    }

    func testDecayOnlyChangesRetention() {
        let original = MasteryVector(exposure: 70, understanding: 68, practice: 64, retention: 80, autonomy: 62)
        let projected = engine.projectDecay(
            original,
            stabilityDays: 10,
            lastEvidenceAt: now.addingTimeInterval(-10 * 86_400),
            now: now
        )

        XCTAssertEqual(projected.exposure, original.exposure)
        XCTAssertEqual(projected.understanding, original.understanding)
        XCTAssertEqual(projected.practice, original.practice)
        XCTAssertEqual(projected.autonomy, original.autonomy)
        XCTAssertEqual(projected.retention, original.retention * exp(-1), accuracy: 0.0001)
    }

    func testStageBoundaries() {
        XCTAssertEqual(MasteryStage.stage(for: 19.999), .entry)
        XCTAssertEqual(MasteryStage.stage(for: 20), .advancing)
        XCTAssertEqual(MasteryStage.stage(for: 40), .proficient)
        XCTAssertEqual(MasteryStage.stage(for: 60), .integrated)
        XCTAssertEqual(MasteryStage.stage(for: 80), .connected)
        XCTAssertEqual(MasteryStage.stage(for: 90), .mastered)
    }

    func testReplayIsChronologicalAndXPNeverBecomesNegative() throws {
        let first = input(current: .zero, kind: .explanation, timestamp: now.addingTimeInterval(-3_600))
        let second = input(current: .zero, kind: .exercise, timestamp: now)
        let result = try XCTUnwrap(engine.replay([second, first]))

        XCTAssertGreaterThanOrEqual(result.xpAwarded, 0)
        XCTAssertGreaterThan(result.updated.composite, 0)
    }

    private func input(
        current: MasteryVector,
        kind: EvidenceKind,
        timestamp: Date? = nil
    ) -> ScoringInput {
        ScoringInput(
            current: current,
            kind: kind,
            difficulty: 1,
            independence: 1,
            confidence: 1,
            stabilityDays: 3,
            lastEvidenceAt: nil,
            timestamp: timestamp ?? now
        )
    }
}
