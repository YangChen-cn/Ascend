import Foundation
import SwiftData

@Model
final class TaxonomySuggestion {
    @Attribute(.unique) var id: UUID
    var suggestionType: String
    var proposedName: String
    var relatedNodeID: UUID?
    var activityID: UUID?
    var evidenceID: UUID?
    var rationale: String
    var confidence: Double
    var status: String
    var createdAt: Date
    var sourceNodeID: UUID?
    var targetNodeID: UUID?
    var relationRawValue: String?
    var targetDomain: String?

    init(
        id: UUID = UUID(),
        suggestionType: String,
        proposedName: String,
        relatedNodeID: UUID? = nil,
        activityID: UUID? = nil,
        evidenceID: UUID? = nil,
        rationale: String,
        confidence: Double,
        status: String = "pending",
        createdAt: Date = .now,
        sourceNodeID: UUID? = nil,
        targetNodeID: UUID? = nil,
        relationRawValue: String? = nil,
        targetDomain: String? = nil
    ) {
        self.id = id
        self.suggestionType = suggestionType
        self.proposedName = proposedName
        self.relatedNodeID = relatedNodeID
        self.activityID = activityID
        self.evidenceID = evidenceID
        self.rationale = rationale
        self.confidence = confidence
        self.status = status
        self.createdAt = createdAt
        self.sourceNodeID = sourceNodeID
        self.targetNodeID = targetNodeID
        self.relationRawValue = relationRawValue
        self.targetDomain = targetDomain
    }
}
