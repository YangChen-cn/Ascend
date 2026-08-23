import Foundation

enum EvidenceCanonicalizer {
    struct Group: Equatable, Sendable {
        let key: String
        let occurredAt: Date
        let evidence: [ChallengeEvidenceSnapshot]
    }

    static func groups(_ evidence: [ChallengeEvidenceSnapshot]) -> [Group] {
        Dictionary(grouping: evidence, by: \.canonicalKey)
            .map { key, snapshots in
                Group(
                    key: key,
                    occurredAt: snapshots.map(\.timestamp).min() ?? .distantFuture,
                    evidence: snapshots.sorted(by: evidenceOrder)
                )
            }
            .sorted { $0.key < $1.key }
    }

    private static func evidenceOrder(
        _ lhs: ChallengeEvidenceSnapshot,
        _ rhs: ChallengeEvidenceSnapshot
    ) -> Bool {
        if lhs.timestamp != rhs.timestamp {
            return lhs.timestamp < rhs.timestamp
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
