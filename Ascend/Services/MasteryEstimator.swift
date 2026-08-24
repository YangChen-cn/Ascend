import Foundation

struct MasteryEstimator: Sendable {
    static let modelVersion = 1
    static let initialProbability = 0.20
    static let fourChoiceGuessProbability = 0.25
    static let defaultSlipProbability = 0.10

    func update(
        prior: Double,
        isCorrect: Bool,
        guessProbability: Double = Self.fourChoiceGuessProbability,
        slipProbability: Double = Self.defaultSlipProbability
    ) -> MasteryUpdate {
        let p = prior.clamped(to: 0.000_001...0.999_999)
        let guess = guessProbability.clamped(to: 0.000_001...0.999_999)
        let slip = slipProbability.clamped(to: 0.000_001...0.999_999)
        let predictedCorrect = p * (1 - slip) + (1 - p) * guess
        let posterior: Double
        if isCorrect {
            posterior = p * (1 - slip) / predictedCorrect
        } else {
            let predictedIncorrect = 1 - predictedCorrect
            posterior = p * slip / predictedIncorrect
        }
        return MasteryUpdate(
            priorProbability: p,
            predictedCorrectProbability: predictedCorrect,
            posteriorProbability: posterior.clamped(to: 0...1)
        )
    }

    func replay(_ observations: [MasteryObservationSnapshot]) -> Double? {
        let validObservations = observations.filter { !$0.isInvalidated }
        guard !validObservations.isEmpty else { return nil }
        var probability = Self.initialProbability
        for observation in validObservations.sorted(by: Self.isEarlier) {
            probability = update(
                prior: probability,
                isCorrect: observation.isCorrect,
                guessProbability: observation.guessProbability,
                slipProbability: observation.slipProbability
            ).posteriorProbability
        }
        return probability
    }

    private static func isEarlier(_ lhs: MasteryObservationSnapshot, _ rhs: MasteryObservationSnapshot) -> Bool {
        lhs.observedAt == rhs.observedAt ? lhs.canonicalKey < rhs.canonicalKey : lhs.observedAt < rhs.observedAt
    }
}

struct MasteryUpdate: Equatable, Sendable {
    let priorProbability: Double
    let predictedCorrectProbability: Double
    let posteriorProbability: Double
}

struct MasteryObservationSnapshot: Equatable, Sendable {
    let canonicalKey: String
    let isCorrect: Bool
    let guessProbability: Double
    let slipProbability: Double
    let observedAt: Date
    let isInvalidated: Bool
}
