import Foundation
import SwiftData

enum AscendSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            AIEndpointProfile.self,
            SourceConfiguration.self,
            ActivityEvent.self,
            EvidenceRecord.self,
            KnowledgeNode.self,
            KnowledgeEdge.self,
            MasteryState.self,
            ScoreLedgerEntry.self,
            TaxonomySuggestion.self,
            Challenge.self,
            DailyDigest.self,
            AnalysisRun.self
        ]
    }

    @Model
    final class TaxonomySuggestion {
        @Attribute(.unique) var id: UUID
        var suggestionType: String
        var proposedName: String
        var relatedNodeID: UUID?
        var activityID: UUID?
        var rationale: String
        var confidence: Double
        var status: String
        var createdAt: Date

        init(
            id: UUID = UUID(),
            suggestionType: String,
            proposedName: String,
            relatedNodeID: UUID? = nil,
            activityID: UUID? = nil,
            rationale: String,
            confidence: Double,
            status: String = "pending",
            createdAt: Date = .now
        ) {
            self.id = id
            self.suggestionType = suggestionType
            self.proposedName = proposedName
            self.relatedNodeID = relatedNodeID
            self.activityID = activityID
            self.rationale = rationale
            self.confidence = confidence
            self.status = status
            self.createdAt = createdAt
        }
    }
}
