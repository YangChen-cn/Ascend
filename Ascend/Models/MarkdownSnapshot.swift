import Foundation

struct MarkdownSnapshot: Identifiable, Codable, Sendable, Equatable {
    var id: String { "\(sourceID.uuidString):\(filePath)" }
    let sourceID: UUID
    let filePath: String
    let contentHash: String
    let content: String
    let modifiedAt: Date

    init(
        sourceID: UUID,
        filePath: String,
        contentHash: String,
        content: String,
        modifiedAt: Date = .now
    ) {
        self.sourceID = sourceID
        self.filePath = filePath
        self.contentHash = contentHash
        self.content = content
        self.modifiedAt = modifiedAt
    }
}
