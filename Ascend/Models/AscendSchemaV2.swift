import SwiftData

enum AscendSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

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
            ReviewPlan.self,
            Challenge.self,
            DailyDigest.self,
            AnalysisRun.self
        ]
    }
}
