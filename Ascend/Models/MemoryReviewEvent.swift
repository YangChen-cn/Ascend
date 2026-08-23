import Foundation
import SwiftData

@Model
final class MemoryReviewEvent {
    @Attribute(.unique) var id: UUID
    var knowledgeNodeID: UUID
    var evidenceID: UUID?
    var canonicalKey: String
    var gradeRawValue: String
    var reviewedAt: Date
    var sourceRawValue: String

    init(
        id: UUID = UUID(),
        knowledgeNodeID: UUID,
        evidenceID: UUID?,
        canonicalKey: String,
        grade: MemoryReviewGrade,
        reviewedAt: Date,
        source: String
    ) {
        self.id = id
        self.knowledgeNodeID = knowledgeNodeID
        self.evidenceID = evidenceID
        self.canonicalKey = canonicalKey
        self.gradeRawValue = grade.rawValue
        self.reviewedAt = reviewedAt
        self.sourceRawValue = source
    }

    var grade: MemoryReviewGrade {
        MemoryReviewGrade(rawValue: gradeRawValue) ?? .good
    }
}
