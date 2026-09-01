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

    /// 领域最高境界按历史掌握度与 XP 两道门槛共同结算。
    var masteryProgress: Double {
        guard let nextRealm else { return 1 }
        let target = max(0.000_001, nextRealm.minimumScore)
        return historicalScore.clamped(to: 0...target) / target
    }

    /// 破境以较短的一块板为准，避免 XP 已满时把尚未达到的掌握门槛误画成满进度。
    var advancementProgress: Double {
        min(xpProgress, masteryProgress)
    }

    /// 下一境的双门槛摘要，供紧凑仪表盘直接说明当前受阻原因。
    var nextRealmGateSummary: String? {
        guard let nextRealm else { return nil }
        let mastery = Int(historicalScore.rounded(.down))
        let targetMastery = Int(nextRealm.minimumScore)
        let masteryMet = historicalScore >= nextRealm.minimumScore
        let xpMet = xp >= nextRealm.minimumXP

        switch (masteryMet, xpMet) {
        case (true, true):
            return "掌握与 XP 均已达标"
        case (true, false):
            return "掌握已达 · XP \(xp.formatted()) / \(nextRealm.minimumXP.formatted())"
        case (false, true):
            return "掌握 \(mastery) / \(targetMastery) · XP 已达"
        case (false, false):
            return "掌握 \(mastery) / \(targetMastery) · XP \(xp.formatted()) / \(nextRealm.minimumXP.formatted())"
        }
    }
}
