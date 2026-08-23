import Foundation
import SwiftData

@Model
final class KnowledgeEdge {
    @Attribute(.unique) var id: UUID
    var sourceNodeID: UUID
    var targetNodeID: UUID
    var relationRawValue: String
    var confidence: Double
    var rationaleText: String?
    var originRawValue: String?
    var createdAtOptional: Date?
    var confirmedAt: Date?

    init(
        id: UUID = UUID(),
        sourceNodeID: UUID,
        targetNodeID: UUID,
        relationRawValue: String,
        confidence: Double,
        rationale: String = "",
        origin: String? = nil,
        createdAt: Date? = nil,
        confirmedAt: Date? = nil
    ) {
        self.id = id
        self.sourceNodeID = sourceNodeID
        self.targetNodeID = targetNodeID
        self.relationRawValue = relationRawValue
        self.confidence = confidence
        self.rationaleText = rationale
        self.originRawValue = origin
        self.createdAtOptional = createdAt
        self.confirmedAt = confirmedAt
    }

    convenience init(
        id: UUID = UUID(),
        sourceNodeID: UUID,
        targetNodeID: UUID,
        relation: KnowledgeRelation,
        confidence: Double,
        rationale: String = "",
        origin: String? = nil,
        createdAt: Date? = nil,
        confirmedAt: Date? = nil
    ) {
        self.init(
            id: id,
            sourceNodeID: sourceNodeID,
            targetNodeID: targetNodeID,
            relationRawValue: relation.rawValue,
            confidence: confidence,
            rationale: rationale,
            origin: origin,
            createdAt: createdAt,
            confirmedAt: confirmedAt
        )
    }

    var relation: KnowledgeRelation {
        get { KnowledgeRelation.from(rawValue: relationRawValue) }
        set { relationRawValue = newValue.rawValue }
    }

    var rationale: String {
        get { rationaleText ?? "" }
        set { rationaleText = newValue }
    }

    var origin: String {
        get { originRawValue ?? "legacyUnknown" }
        set { originRawValue = newValue }
    }

    var createdAt: Date? {
        get { createdAtOptional }
        set { createdAtOptional = newValue }
    }
}
