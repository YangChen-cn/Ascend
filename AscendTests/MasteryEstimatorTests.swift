import XCTest
@testable import Ascend

final class MasteryEstimatorTests: XCTestCase {
    private let estimator = MasteryEstimator()

    func testVersionedBKTUpdateUsesDeclaredGuessAndSlipRates() {
        let correct = estimator.update(prior: 0.20, isCorrect: true)
        let incorrect = estimator.update(prior: 0.20, isCorrect: false)

        XCTAssertEqual(MasteryEstimator.modelVersion, 1)
        XCTAssertEqual(correct.predictedCorrectProbability, 0.38, accuracy: 0.000_001)
        XCTAssertEqual(correct.posteriorProbability, 0.473_684_2105, accuracy: 0.000_001)
        XCTAssertEqual(incorrect.posteriorProbability, 0.032_258_0645, accuracy: 0.000_001)
        XCTAssertGreaterThan(correct.posteriorProbability, 0.20)
        XCTAssertLessThan(incorrect.posteriorProbability, 0.20)
    }

    func testReplayIsDeterministicAndIgnoresInvalidatedObservations() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let observations = [
            snapshot("b", correct: false, at: start.addingTimeInterval(2)),
            snapshot("a", correct: true, at: start),
            snapshot("invalid", correct: true, at: start.addingTimeInterval(1), invalidated: true)
        ]
        let expected = estimator.update(
            prior: estimator.update(prior: 0.20, isCorrect: true).posteriorProbability,
            isCorrect: false
        ).posteriorProbability

        let replayed = try XCTUnwrap(estimator.replay(observations))
        XCTAssertEqual(replayed, expected, accuracy: 0.000_001)
        XCTAssertNil(estimator.replay([snapshot("invalid", correct: true, at: start, invalidated: true)]))
    }

    private func snapshot(
        _ key: String,
        correct: Bool,
        at date: Date,
        invalidated: Bool = false
    ) -> MasteryObservationSnapshot {
        MasteryObservationSnapshot(
            canonicalKey: key,
            isCorrect: correct,
            guessProbability: 0.25,
            slipProbability: 0.10,
            observedAt: date,
            isInvalidated: invalidated
        )
    }
}
