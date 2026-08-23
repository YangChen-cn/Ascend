import Foundation

struct EdgeSuggestion: Codable, Identifiable, Sendable {
    let id: UUID
    let sourceName: String
    let targetName: String
    let relation: String
    let confidence: Double
}
