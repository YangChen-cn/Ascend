import SwiftData

enum AscendSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            AIEndpointProfile.self,
            SourceConfiguration.self,
            ActivityEvent.self,
            ActivityTrackingExclusion.self,
            EvidenceRecord.self,
            KnowledgeNode.self,
            KnowledgeEdge.self,
            MasteryState.self,
            ScoreLedgerEntry.self,
            TaxonomySuggestion.self,
            ReviewPlan.self,
            Challenge.self,
            DailyDigest.self,
            AnalysisRun.self
        ]
    }
}
