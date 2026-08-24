import Foundation

struct DomainProgressSnapshot: Identifiable, Sendable {
    let name: String
    let historicalScore: Double
    let currentScore: Double
    let xp: Int
    let knowledgeCount: Int
    let realm: DomainRealm
    let currentRealm: DomainRealm

    var id: String { name }

    var score: Double { currentScore }

    var nextRealm: DomainRealm? { realm.next }

    var xpProgress: Double {
        guard let nextRealm else { return 1 }
        let target = max(1, nextRealm.minimumXP)
        return Double(xp.clamped(to: 0...target)) / Double(target)
    }
}
