import Foundation
import SwiftData

@Model
final class TaxonomySuggestion {
    @Attribute(.unique) var id: UUID
    var suggestionType: String
    var proposedName: String
    var relatedNodeID: UUID?
    var rationale: String
    var confidence: Double
    var status: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        suggestionType: String,
        proposedName: String,
        relatedNodeID: UUID? = nil,
        rationale: String,
        confidence: Double,
        status: String = "pending",
        createdAt: Date = .now
    ) {
        self.id = id
        self.suggestionType = suggestionType
        self.proposedName = proposedName
        self.relatedNodeID = relatedNodeID
        self.rationale = rationale
        self.confidence = confidence
        self.status = status
        self.createdAt = createdAt
    }
}
