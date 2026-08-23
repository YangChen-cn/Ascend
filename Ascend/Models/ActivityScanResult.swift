import Foundation

struct ActivityScanResult: Sendable {
    let activities: [CollectedActivity]
    let nextCursor: String?
    let scannedAt: Date
    let markdownSnapshotMutations: [MarkdownSnapshotMutation]

    init(
        activities: [CollectedActivity],
        nextCursor: String? = nil,
        scannedAt: Date = .now,
        markdownSnapshotMutations: [MarkdownSnapshotMutation] = []
    ) {
        self.activities = activities
        self.nextCursor = nextCursor
        self.scannedAt = scannedAt
        self.markdownSnapshotMutations = markdownSnapshotMutations
    }
}
