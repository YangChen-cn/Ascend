import Foundation

struct DomainProgressSnapshot: Identifiable, Sendable {
    let name: String
    let score: Double
    let xp: Int
    let knowledgeCount: Int
    let realm: DomainRealm

    var id: String { name }

    var nextRealm: DomainRealm? { realm.next }

    var xpProgress: Double {
        guard let nextRealm else { return 1 }
        let lower = realm.minimumXP
        let range = max(1, nextRealm.minimumXP - lower)
        return Double((xp - lower).clamped(to: 0...range)) / Double(range)
    }
}
