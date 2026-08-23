import Foundation

struct TrajectoryPoint: Identifiable, Sendable {
    let id: String
    let timestamp: Date
    let score: Double
    let reason: String?
    let evidenceID: UUID?

    static func make(from entries: [ScoreLedgerEntry]) -> [Self] {
        let sorted = entries.sorted { $0.timestamp < $1.timestamp }
        guard let first = sorted.first else { return [] }
        var points = [
            Self(
                id: "\(first.id.uuidString)-previous",
                timestamp: first.timestamp,
                score: first.previousComposite,
                reason: nil,
                evidenceID: first.evidenceID
            )
        ]
        points += sorted.map { entry in
            Self(
                id: entry.id.uuidString,
                timestamp: entry.timestamp,
                score: entry.newComposite,
                reason: entry.reason,
                evidenceID: entry.evidenceID
            )
        }
        return points
    }
}
