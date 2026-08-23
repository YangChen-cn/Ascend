import Foundation

struct ExportBundle: Codable, Sendable {
    let exportedAt: Date
    let knowledgeNodes: [ExportedKnowledgeNode]
    let masteryStates: [ExportedMasteryState]
    let evidence: [ExportedEvidence]
    let sources: [ExportedSource]
    let endpoints: [ExportedEndpoint]
    let challenges: [ExportedChallenge]
    let digests: [ExportedDigest]
    let reviewPlans: [ExportedReviewPlan]?
    let activityTrackingExclusions: [ExportedActivityTrackingExclusion]?
    let realmAdvancements: [ExportedRealmAdvancement]?
    let knowledgeEdges: [ExportedKnowledgeEdge]?
    let memoryReviewEvents: [ExportedMemoryReviewEvent]?
    let scoreLedgerEntries: [ExportedScoreLedgerEntry]?
}
