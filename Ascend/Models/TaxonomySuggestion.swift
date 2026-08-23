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
    var prerequisiteNodeIDsJSON: String?

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
        targetDomain: String? = nil,
        prerequisiteNodeIDs: [UUID] = []
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
        if !prerequisiteNodeIDs.isEmpty,
           let data = try? JSONEncoder().encode(prerequisiteNodeIDs),
           let json = String(data: data, encoding: .utf8) {
            self.prerequisiteNodeIDsJSON = json
        } else {
            self.prerequisiteNodeIDsJSON = nil
        }
    }

    var prerequisiteNodeIDs: [UUID] {
        get {
            guard let data = prerequisiteNodeIDsJSON?.data(using: .utf8),
                  let ids = try? JSONDecoder().decode([UUID].self, from: data) else {
                return []
            }
            return ids
        }
        set {
            if newValue.isEmpty {
                prerequisiteNodeIDsJSON = nil
            } else if let data = try? JSONEncoder().encode(newValue),
                      let json = String(data: data, encoding: .utf8) {
                prerequisiteNodeIDsJSON = json
            }
        }
    }
}
