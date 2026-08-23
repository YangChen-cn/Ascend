import Foundation

struct AnalysisEnvelope: Codable, Sendable {
    let sessionSummary: String
    let evidence: [AnalyzedEvidence]
    let nodeSuggestions: [NodeSuggestion]
    let edgeSuggestions: [EdgeSuggestion]
    let challengeSuggestion: ChallengeSuggestion?
}
