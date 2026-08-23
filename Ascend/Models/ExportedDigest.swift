import Foundation

struct ExportedDigest: Codable, Sendable {
    let date: Date
    let summary: String
    let xpEarned: Int
}
