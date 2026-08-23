import Foundation

struct EdgeSuggestion: Codable, Identifiable, Sendable {
    let id: UUID
    let sourceName: String
    let targetName: String
    let relation: String
    let confidence: Double

    init(
        id: UUID = UUID(),
        sourceName: String,
        targetName: String,
        relation: String,
        confidence: Double
    ) {
        self.id = id
        self.sourceName = sourceName
        self.targetName = targetName
        self.relation = relation
        self.confidence = confidence
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case sourceName
        case targetName
        case relation
        case confidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        sourceName = try container.decode(String.self, forKey: .sourceName)
        targetName = try container.decode(String.self, forKey: .targetName)
        relation = try container.decode(String.self, forKey: .relation)
        confidence = try container.decode(Double.self, forKey: .confidence)
    }
}
