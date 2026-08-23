import Foundation

struct ExportedScoreLedgerEntry: Codable, Sendable {
    let id: UUID
    let evidenceID: UUID
    let knowledgeNodeID: UUID
    let timestamp: Date
    let previousComposite: Double
    let newComposite: Double
    let xpAwarded: Int
    let reason: String
}
