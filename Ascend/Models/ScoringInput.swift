import Foundation

struct ScoringInput: Sendable {
    let current: MasteryVector
    let kind: EvidenceKind
    let difficulty: Double
    let independence: Double
    let confidence: Double
    let stabilityDays: Double
    let lastEvidenceAt: Date?
    let timestamp: Date
}
