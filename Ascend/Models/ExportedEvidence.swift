import Foundation

struct ExportedEvidence: Codable, Sendable {
    let id: UUID
    let activityID: UUID?
    let knowledgeNodeID: UUID
    let kind: EvidenceKind
    let timestamp: Date
    let summary: String
    let rationale: String
    let difficulty: Double?
    let independence: Double?
    let aiConfidence: Double?
    let isVerified: Bool
    let fingerprint: String?
    let contentChangeHash: String?
}
