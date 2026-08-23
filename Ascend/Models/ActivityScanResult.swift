import Foundation

struct ActivityScanResult: Sendable {
    let activities: [CollectedActivity]
    let nextCursor: String?
    let upstreamReference: String?
    let remoteURLString: String?
    let scannedAt: Date
    let markdownSnapshotMutations: [MarkdownSnapshotMutation]

    init(
        activities: [CollectedActivity],
        nextCursor: String? = nil,
        upstreamReference: String? = nil,
        remoteURLString: String? = nil,
        scannedAt: Date = .now,
        markdownSnapshotMutations: [MarkdownSnapshotMutation] = []
    ) {
        self.activities = activities
        self.nextCursor = nextCursor
        self.upstreamReference = upstreamReference
        self.remoteURLString = remoteURLString
        self.scannedAt = scannedAt
        self.markdownSnapshotMutations = markdownSnapshotMutations
    }
}
