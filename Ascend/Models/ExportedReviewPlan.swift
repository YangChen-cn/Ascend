import Foundation

struct ExportedReviewPlan: Codable, Sendable {
    let id: UUID
    let knowledgeNodeID: UUID
    let createdAt: Date
    let scheduledAt: Date
    let reason: String
    let status: String
}
