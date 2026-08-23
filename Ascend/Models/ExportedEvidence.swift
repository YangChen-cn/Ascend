import Foundation

struct ExportedEvidence: Codable, Sendable {
    let id: UUID
    let knowledgeNodeID: UUID
    let kind: EvidenceKind
    let timestamp: Date
    let summary: String
    let rationale: String
    let isVerified: Bool
}
