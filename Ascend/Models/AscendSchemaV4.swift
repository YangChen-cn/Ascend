import SwiftData

enum AscendSchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)

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
            ChallengeAutomationState.self,
            RealmAdvancementEvent.self,
            AutomationReceipt.self,
            AnalysisBatchSummary.self,
            DailyDigest.self,
            AnalysisRun.self
        ]
    }
}
