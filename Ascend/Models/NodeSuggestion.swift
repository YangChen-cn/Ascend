import Foundation

struct NodeSuggestion: Codable, Identifiable, Sendable {
    let id: UUID
    let proposedName: String
    let domain: String
    let confidence: Double
    let rationale: String
}
