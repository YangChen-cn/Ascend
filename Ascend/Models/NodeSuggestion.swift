import Foundation

struct NodeSuggestion: Codable, Identifiable, Sendable {
    let id: UUID
    let proposedName: String
    let domain: String
    let confidence: Double
    let rationale: String

    init(
        id: UUID = UUID(),
        proposedName: String,
        domain: String,
        confidence: Double,
        rationale: String
    ) {
        self.id = id
        self.proposedName = proposedName
        self.domain = domain
        self.confidence = confidence
        self.rationale = rationale
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case proposedName
        case domain
        case confidence
        case rationale
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        proposedName = try container.decode(String.self, forKey: .proposedName)
        domain = try container.decode(String.self, forKey: .domain)
        confidence = try container.decode(Double.self, forKey: .confidence)
        rationale = try container.decode(String.self, forKey: .rationale)
    }
}
