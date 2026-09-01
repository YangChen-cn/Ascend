import Foundation

struct AnalyzedEvidence: Codable, Identifiable, Sendable {
    let id: UUID
    let activityID: UUID
    let knowledgeName: String
    let matchedNodeID: UUID?
    let matchConfidence: Double
    let kind: EvidenceKind
    let difficulty: Double
    let independence: Double
    let confidence: Double
    let coverage: Double
    let summary: String
    let rationale: String

    init(
        id: UUID = UUID(),
        activityID: UUID,
        knowledgeName: String,
        matchedNodeID: UUID?,
        matchConfidence: Double,
        kind: EvidenceKind,
        difficulty: Double,
        independence: Double,
        confidence: Double,
        coverage: Double? = nil,
        summary: String,
        rationale: String
    ) {
        self.id = id
        self.activityID = activityID
        self.knowledgeName = knowledgeName
        self.matchedNodeID = matchedNodeID
        self.matchConfidence = matchConfidence
        self.kind = kind
        self.difficulty = difficulty
        self.independence = independence
        self.confidence = confidence
        self.coverage = ArtifactCoveragePolicy.normalized(coverage, for: kind)
        self.summary = summary
        self.rationale = rationale
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case activityID
        case knowledgeName
        case matchedNodeID
        case matchConfidence
        case kind
        case difficulty
        case independence
        case confidence
        case coverage
        case summary
        case rationale
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        activityID = try container.decode(UUID.self, forKey: .activityID)
        knowledgeName = try container.decode(String.self, forKey: .knowledgeName)
        matchedNodeID = try container.decodeIfPresent(UUID.self, forKey: .matchedNodeID)
        matchConfidence = try container.decode(Double.self, forKey: .matchConfidence)
        kind = try container.decode(EvidenceKind.self, forKey: .kind)
        difficulty = try container.decode(Double.self, forKey: .difficulty)
        independence = try container.decode(Double.self, forKey: .independence)
        confidence = try container.decode(Double.self, forKey: .confidence)
        coverage = ArtifactCoveragePolicy.normalized(
            try container.decodeIfPresent(Double.self, forKey: .coverage),
            for: kind
        )
        summary = try container.decode(String.self, forKey: .summary)
        rationale = try container.decode(String.self, forKey: .rationale)
    }
}
