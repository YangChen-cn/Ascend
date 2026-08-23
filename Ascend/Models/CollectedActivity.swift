import Foundation

struct CollectedActivity: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let sourceID: UUID
    let sourceKind: SourceKind
    let timestamp: Date
    let fingerprint: String
    let contentChangeHash: String?
    let title: String
    let sourceLocator: String
    let summary: String
    let excerpt: String

    init(
        id: UUID = UUID(),
        sourceID: UUID,
        sourceKind: SourceKind,
        timestamp: Date,
        fingerprint: String,
        contentChangeHash: String? = nil,
        title: String,
        sourceLocator: String,
        summary: String,
        excerpt: String
    ) {
        self.id = id
        self.sourceID = sourceID
        self.sourceKind = sourceKind
        self.timestamp = timestamp
        self.fingerprint = fingerprint
        self.contentChangeHash = contentChangeHash
        self.title = title
        self.sourceLocator = sourceLocator
        self.summary = summary
        self.excerpt = excerpt
    }
}
