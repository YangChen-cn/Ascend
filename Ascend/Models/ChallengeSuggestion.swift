import Foundation

struct ChallengeSuggestion: Codable, Sendable {
    let title: String
    let description: String
    let estimatedMinutes: Int
    let requirements: [String]
    let rewardXP: Int
}
