import Foundation

struct ExportedKnowledgeEdge: Codable, Sendable {
    let id: UUID
    let sourceNodeID: UUID
    let targetNodeID: UUID
    let relationRawValue: String
    let confidence: Double
}
