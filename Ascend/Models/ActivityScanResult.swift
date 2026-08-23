import Foundation

struct ActivityScanResult: Sendable {
    let activities: [CollectedActivity]
    let nextCursor: String?
    let scannedAt: Date

    init(
        activities: [CollectedActivity],
        nextCursor: String? = nil,
        scannedAt: Date = .now
    ) {
        self.activities = activities
        self.nextCursor = nextCursor
        self.scannedAt = scannedAt
    }
}
