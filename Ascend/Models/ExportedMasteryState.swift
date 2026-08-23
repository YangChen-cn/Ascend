import Foundation

struct ExportedMasteryState: Codable, Sendable {
    let knowledgeNodeID: UUID
    let vector: MasteryVector
    let confidence: Double
    let stabilityDays: Double
    let lastEvidenceAt: Date?
    let lifetimeXP: Int
    let highestStageRawValue: String?
}
