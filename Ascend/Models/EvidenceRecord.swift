import Foundation
import SwiftData

@Model
final class EvidenceRecord {
    @Attribute(.unique) var id: UUID
    var activityID: UUID
    var knowledgeNodeID: UUID
    var kindRawValue: String
    var timestamp: Date
    var summary: String
    var rationale: String
    var difficulty: Double
    var independence: Double
    var aiConfidence: Double
    var isVerified: Bool
    var fingerprint: String

    init(
        id: UUID = UUID(),
        activityID: UUID,
        knowledgeNodeID: UUID,
        kind: EvidenceKind,
        timestamp: Date,
        summary: String,
        rationale: String,
        difficulty: Double,
        independence: Double,
        aiConfidence: Double,
        isVerified: Bool,
        fingerprint: String
    ) {
        self.id = id
        self.activityID = activityID
        self.knowledgeNodeID = knowledgeNodeID
        self.kindRawValue = kind.rawValue
        self.timestamp = timestamp
        self.summary = summary
        self.rationale = rationale
        self.difficulty = difficulty
        self.independence = independence
        self.aiConfidence = aiConfidence
        self.isVerified = isVerified
        self.fingerprint = fingerprint
    }

    var kind: EvidenceKind {
        EvidenceKind(rawValue: kindRawValue) ?? .exposure
    }
}
