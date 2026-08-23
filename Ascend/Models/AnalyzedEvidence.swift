import Foundation

struct AnalyzedEvidence: Codable, Identifiable, Sendable {
    let id: UUID
    let activityID: UUID
    let knowledgeName: String
    let matchedNodeID: UUID?
    let matchConfidence: Double
    let kind: EvidenceKind
    let difficulty: Double
    let independence: Double
    let confidence: Double
    let summary: String
    let rationale: String
}
