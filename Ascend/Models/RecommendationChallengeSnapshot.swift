import Foundation

struct RecommendationChallengeSnapshot: Sendable {
    let id: UUID
    let title: String
    let knowledgeNodeIDs: Set<UUID>
    let status: String
}
