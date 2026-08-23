import Foundation
import SwiftData

@Model
final class Challenge {
    @Attribute(.unique) var id: UUID
    var title: String
    var challengeDescription: String
    var estimatedMinutes: Int
    var knowledgeNodeIDsJSON: String
    var requirementsJSON: String
    var rewardXP: Int
    var status: String
    var createdAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        challengeDescription: String,
        estimatedMinutes: Int,
        knowledgeNodeIDs: [UUID],
        requirements: [String],
        rewardXP: Int,
        status: String = "unlocked",
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.challengeDescription = challengeDescription
        self.estimatedMinutes = estimatedMinutes
        self.knowledgeNodeIDsJSON = Self.encode(knowledgeNodeIDs)
        self.requirementsJSON = Self.encode(requirements)
        self.rewardXP = rewardXP
        self.status = status
        self.createdAt = createdAt
    }

    var knowledgeNodeIDs: [UUID] { Self.decode([UUID].self, from: knowledgeNodeIDsJSON) ?? [] }
    var requirements: [String] { Self.decode([String].self, from: requirementsJSON) ?? [] }

    private static func encode<T: Encodable>(_ value: T) -> String {
        String(data: (try? JSONEncoder().encode(value)) ?? Data(), encoding: .utf8) ?? "[]"
    }

    private static func decode<T: Decodable>(_ type: T.Type, from string: String) -> T? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
