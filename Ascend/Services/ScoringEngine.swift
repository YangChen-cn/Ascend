import Foundation

struct ScoringEngine: Sendable {
    func apply(_ input: ScoringInput) -> ScoringResult {
        let difficultyFactor = input.difficulty.clamped(to: 0.8...1.2)
        let independenceFactor = input.independence.clamped(to: 0.8...1.2)
        let confidenceFactor = input.confidence.clamped(to: 0.5...1.0)
        let scaledStrength = input.kind.baseStrength * difficultyFactor * independenceFactor * confidenceFactor
        let allocation = allocation(for: input.kind)

        let updated = MasteryVector(
            exposure: score(input.current.exposure, strength: scaledStrength * allocation.exposure),
            understanding: score(input.current.understanding, strength: scaledStrength * allocation.understanding),
            practice: score(input.current.practice, strength: scaledStrength * allocation.practice),
            retention: input.current.retention,
            autonomy: score(input.current.autonomy, strength: scaledStrength * allocation.autonomy)
        ).clamped()

        let positiveCompositeGain = max(0, updated.composite - input.current.composite)
        let xpAwarded = Int((positiveCompositeGain * 10).rounded())
        return ScoringResult(
            previous: input.current,
            updated: updated,
            xpAwarded: xpAwarded,
            stabilityDays: input.stabilityDays
        )
    }

    private func score(_ current: Double, strength: Double) -> Double {
        let diminishing = max(0, 1 - current / 100)
        let delta = min(12, strength * diminishing)
        return current + delta
    }

    private func allocation(for kind: EvidenceKind) -> MasteryVector {
        switch kind {
        case .exposure:
            MasteryVector(exposure: 1, understanding: 0.15, practice: 0, retention: 0, autonomy: 0)
        case .explanation:
            MasteryVector(exposure: 0.25, understanding: 1, practice: 0.15, retention: 0, autonomy: 0.10)
        case .exercise:
            MasteryVector(exposure: 0.15, understanding: 0.35, practice: 1, retention: 0, autonomy: 0.20)
        case .project:
            MasteryVector(exposure: 0.15, understanding: 0.40, practice: 1, retention: 0, autonomy: 0.55)
        case .review:
            MasteryVector(exposure: 0.05, understanding: 0.25, practice: 0.20, retention: 0, autonomy: 0.15)
        case .independentSolve:
            MasteryVector(exposure: 0.10, understanding: 0.45, practice: 0.70, retention: 0, autonomy: 1)
        }
    }
}
