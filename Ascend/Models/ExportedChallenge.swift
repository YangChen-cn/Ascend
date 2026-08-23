import Foundation

struct ExportedChallenge: Codable, Sendable {
    let id: UUID
    let title: String
    let description: String
    let status: String
    let rewardXP: Int
}
