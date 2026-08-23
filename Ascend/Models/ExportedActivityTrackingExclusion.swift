import Foundation

struct ExportedActivityTrackingExclusion: Codable, Sendable {
    let id: UUID
    let sourceID: UUID
    let sourceKind: SourceKind
    let sourceLocator: String
    let createdAt: Date
    let reason: String
}
