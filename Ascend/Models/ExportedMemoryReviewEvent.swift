import Foundation

struct ExportedMemoryReviewEvent: Codable, Sendable {
    let id: UUID
    let knowledgeNodeID: UUID
    let evidenceID: UUID?
    let canonicalKey: String
    let gradeRawValue: String
    let reviewedAt: Date
    let sourceRawValue: String
}
