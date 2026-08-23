import Foundation

struct NextConceptSuggestion: Codable, Identifiable, Sendable {
    let id: UUID
    let proposedName: String
    let domain: String
    let prerequisiteNames: [String]
    let rationale: String
    let confidence: Double

    init(
        id: UUID = UUID(),
        proposedName: String,
        domain: String,
        prerequisiteNames: [String] = [],
        rationale: String,
        confidence: Double
    ) {
        self.id = id
        self.proposedName = proposedName
        self.domain = domain
        self.prerequisiteNames = prerequisiteNames
        self.rationale = rationale
        self.confidence = confidence
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case proposedName
        case domain
        case prerequisiteNames
        case rationale
        case confidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        proposedName = try container.decode(String.self, forKey: .proposedName)
        domain = try container.decodeIfPresent(String.self, forKey: .domain) ?? "通用"
        prerequisiteNames = try container.decodeIfPresent([String].self, forKey: .prerequisiteNames) ?? []
        rationale = try container.decode(String.self, forKey: .rationale)
        confidence = try container.decode(Double.self, forKey: .confidence)
    }
}
