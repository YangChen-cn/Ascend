import Foundation

struct ExportedChallenge: Codable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let status: String
    let rewardXP: Int
    let estimatedMinutes: Int?
    let knowledgeNodeIDs: [UUID]?
    let requirements: [String]?
    let structuredRequirement: ChallengeRequirement?
    let acceptedAt: Date?
    let completedAt: Date?
}
