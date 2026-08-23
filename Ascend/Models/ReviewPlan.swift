import Foundation
import SwiftData

@Model
final class ReviewPlan {
    @Attribute(.unique) var id: UUID
    var knowledgeNodeID: UUID
    var createdAt: Date
    var scheduledAt: Date
    var reason: String
    var status: String

    init(
        id: UUID = UUID(),
        knowledgeNodeID: UUID,
        createdAt: Date = .now,
        scheduledAt: Date,
        reason: String,
        status: String = "scheduled"
    ) {
        self.id = id
        self.knowledgeNodeID = knowledgeNodeID
        self.createdAt = createdAt
        self.scheduledAt = scheduledAt
        self.reason = reason
        self.status = status
    }
}
