import Foundation

struct KnowledgeCandidate: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let domain: String
    let mastery: Double
}
