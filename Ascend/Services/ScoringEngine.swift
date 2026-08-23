import Foundation

struct ScoringEngine: Sendable {
    func apply(_ input: ScoringInput) -> ScoringResult {
        let decayed = projectDecay(
            input.current,
            stabilityDays: input.stabilityDays,
            lastEvidenceAt: input.lastEvidenceAt,
            now: input.timestamp
        )
        let difficultyFactor = input.difficulty.clamped(to: 0.8...1.2)
        let independenceFactor = input.independence.clamped(to: 0.8...1.2)
        let confidenceFactor = input.confidence.clamped(to: 0.5...1.0)
        let scaledStrength = input.kind.baseStrength * difficultyFactor * independenceFactor * confidenceFactor
        let allocation = allocation(for: input.kind)

        let updated = MasteryVector(
            exposure: score(decayed.exposure, strength: scaledStrength * allocation.exposure),
            understanding: score(decayed.understanding, strength: scaledStrength * allocation.understanding),
            practice: score(decayed.practice, strength: scaledStrength * allocation.practice),
            retention: score(decayed.retention, strength: scaledStrength * allocation.retention),
            autonomy: score(decayed.autonomy, strength: scaledStrength * allocation.autonomy)
        ).clamped()

        let positiveCompositeGain = max(0, updated.composite - decayed.composite)
        let xpAwarded = Int((positiveCompositeGain * 10).rounded())
        let newStability = stabilityAfterEvidence(
            current: input.stabilityDays,
            kind: input.kind,
            confidence: input.confidence
        )
        return ScoringResult(
            previous: decayed,
            updated: updated,
            xpAwarded: xpAwarded,
            stabilityDays: newStability
        )
    }

    func projectDecay(
        _ vector: MasteryVector,
        stabilityDays: Double,
        lastEvidenceAt: Date?,
        now: Date
    ) -> MasteryVector {
        guard let lastEvidenceAt, now > lastEvidenceAt else { return vector }
        let elapsedDays = now.timeIntervalSince(lastEvidenceAt) / 86_400
        let retentionFactor = exp(-elapsedDays / max(3, stabilityDays))
        var projected = vector
        projected.retention *= retentionFactor
        return projected.clamped()
    }

    func replay(_ inputs: [ScoringInput]) -> ScoringResult? {
        guard let first = inputs.sorted(by: { $0.timestamp < $1.timestamp }).first else { return nil }
        var vector = first.current
        var stability = first.stabilityDays
        var lastDate = first.lastEvidenceAt
        var totalXP = 0
        var finalResult: ScoringResult?

        for input in inputs.sorted(by: { $0.timestamp < $1.timestamp }) {
            let result = apply(
                ScoringInput(
                    current: vector,
                    kind: input.kind,
                    difficulty: input.difficulty,
                    independence: input.independence,
                    confidence: input.confidence,
                    stabilityDays: stability,
                    lastEvidenceAt: lastDate,
                    timestamp: input.timestamp
                )
            )
            vector = result.updated
            stability = result.stabilityDays
            lastDate = input.timestamp
            totalXP += result.xpAwarded
            finalResult = ScoringResult(
                previous: first.current,
                updated: vector,
                xpAwarded: totalXP,
                stabilityDays: stability
            )
        }
        return finalResult
    }

    private func score(_ current: Double, strength: Double) -> Double {
        let diminishing = max(0, 1 - current / 100)
        let delta = min(12, strength * diminishing)
        return current + delta
    }

    private func allocation(for kind: EvidenceKind) -> MasteryVector {
        switch kind {
        case .exposure:
            MasteryVector(exposure: 1, understanding: 0.15, practice: 0, retention: 0.10, autonomy: 0)
        case .explanation:
            MasteryVector(exposure: 0.25, understanding: 1, practice: 0.15, retention: 0.20, autonomy: 0.10)
        case .exercise:
            MasteryVector(exposure: 0.15, understanding: 0.35, practice: 1, retention: 0.25, autonomy: 0.20)
        case .project:
            MasteryVector(exposure: 0.15, understanding: 0.40, practice: 1, retention: 0.35, autonomy: 0.55)
        case .review:
            MasteryVector(exposure: 0.05, understanding: 0.25, practice: 0.20, retention: 1, autonomy: 0.15)
        case .independentSolve:
            MasteryVector(exposure: 0.10, understanding: 0.45, practice: 0.70, retention: 0.30, autonomy: 1)
        }
    }

    private func stabilityAfterEvidence(current: Double, kind: EvidenceKind, confidence: Double) -> Double {
        let multiplier: Double
        switch kind {
        case .review: multiplier = 1.6
        case .project: multiplier = 1.5
        case .independentSolve: multiplier = 1.7
        case .exercise: multiplier = 1.25
        case .explanation: multiplier = 1.15
        case .exposure: multiplier = 1.05
        }
        return min(180, max(3, current * (1 + (multiplier - 1) * confidence.clamped(to: 0.5...1))))
    }
}
