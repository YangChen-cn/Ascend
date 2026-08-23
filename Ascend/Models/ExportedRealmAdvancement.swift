import Foundation

struct ExportedRealmAdvancement: Codable, Sendable {
    let id: UUID
    let evidenceID: UUID
    let knowledgeNodeID: UUID
    let previousStage: MasteryStage
    let newStage: MasteryStage
    let occurredAt: Date
}
