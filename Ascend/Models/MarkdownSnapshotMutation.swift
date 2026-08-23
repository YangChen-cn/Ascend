import Foundation

enum MarkdownSnapshotMutation: Sendable, Equatable {
    case save(MarkdownSnapshot)
    case remove(sourceID: UUID, filePath: String)
    case rename(sourceID: UUID, oldPath: String, newPath: String)
}
