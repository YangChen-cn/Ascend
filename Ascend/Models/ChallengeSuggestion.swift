import Foundation

struct ChallengeSuggestion: Codable, Sendable {
    let title: String
    let description: String
    let estimatedMinutes: Int
    let knowledgeNames: [String]
    let requirement: ChallengeRequirement
    let rewardXP: Int

    init(
        title: String,
        description: String,
        estimatedMinutes: Int,
        knowledgeNames: [String],
        requirement: ChallengeRequirement,
        rewardXP: Int
    ) {
        self.title = title
        self.description = description
        self.estimatedMinutes = estimatedMinutes
        self.knowledgeNames = knowledgeNames
        self.requirement = requirement
        self.rewardXP = rewardXP
    }
}
