import Foundation

struct AnalysisEnvelope: Codable, Sendable {
    let sessionSummary: String
    let evidence: [AnalyzedEvidence]
    let nodeSuggestions: [NodeSuggestion]
    let edgeSuggestions: [EdgeSuggestion]
    let challengeSuggestion: ChallengeSuggestion?
    let possibleNextConcepts: [NextConceptSuggestion]

    init(
        sessionSummary: String,
        evidence: [AnalyzedEvidence],
        nodeSuggestions: [NodeSuggestion],
        edgeSuggestions: [EdgeSuggestion],
        challengeSuggestion: ChallengeSuggestion?,
        possibleNextConcepts: [NextConceptSuggestion] = []
    ) {
        self.sessionSummary = sessionSummary
        self.evidence = evidence
        self.nodeSuggestions = nodeSuggestions
        self.edgeSuggestions = edgeSuggestions
        self.challengeSuggestion = challengeSuggestion
        self.possibleNextConcepts = possibleNextConcepts
    }

    private enum CodingKeys: String, CodingKey {
        case sessionSummary
        case evidence
        case nodeSuggestions
        case edgeSuggestions
        case challengeSuggestion
        case possibleNextConcepts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionSummary = try container.decode(String.self, forKey: .sessionSummary)
        evidence = try container.decode([AnalyzedEvidence].self, forKey: .evidence)
        nodeSuggestions = try container.decodeIfPresent([NodeSuggestion].self, forKey: .nodeSuggestions) ?? []
        edgeSuggestions = try container.decodeIfPresent([EdgeSuggestion].self, forKey: .edgeSuggestions) ?? []
        challengeSuggestion = try container.decodeIfPresent(ChallengeSuggestion.self, forKey: .challengeSuggestion)
        possibleNextConcepts = try container.decodeIfPresent([NextConceptSuggestion].self, forKey: .possibleNextConcepts) ?? []
    }
}
