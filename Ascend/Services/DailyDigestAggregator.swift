import Foundation

struct DailyDigestSnapshot: Equatable, Sendable {
    let date: Date
    let summary: String
    let improvedNodeIDs: [UUID]
    let forgettingNodeIDs: [UUID]
    let xpEarned: Int
}

struct DailyDigestAggregator: Sendable {
    func aggregate(
        date: Date,
        batchSummaries: [String],
        nodes: [KnowledgeNode],
        ledgerEntries: [ScoreLedgerEntry],
        forgetting: [ForgettingProjection],
        dueReviewPlans: [ReviewPlan],
        completedChallenges: [Challenge],
        calendar: Calendar = .current
    ) -> DailyDigestSnapshot {
        let day = calendar.startOfDay(for: date)
        let dayLedger = ledgerEntries.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
        let nodeByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let grouped = Dictionary(grouping: dayLedger, by: \.knowledgeNodeID)
        let improvements = grouped.compactMap { nodeID, entries -> (UUID, Double)? in
            guard let first = entries.min(by: { $0.timestamp < $1.timestamp }),
                  let last = entries.max(by: { $0.timestamp < $1.timestamp }) else { return nil }
            return (nodeID, last.newComposite - first.previousComposite)
        }.sorted { $0.1 > $1.1 }
        let xp = dayLedger.reduce(0) { $0 + $1.xpAwarded }
        let uniqueSummaries = batchSummaries.reduce(into: [String]()) { result, summary in
            let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !result.contains(trimmed) { result.append(trimmed) }
        }

        var sections: [String] = []
        if !uniqueSummaries.isEmpty {
            sections.append("今日所学：" + uniqueSummaries.joined(separator: "；"))
        }
        if let strongest = improvements.first, let node = nodeByID[strongest.0] {
            sections.append("最重要成长：\(node.name) 提升 \(Int(max(0, strongest.1).rounded())) 点")
        }
        if xp > 0 { sections.append("真实知识 XP：+\(xp)") }
        if !dueReviewPlans.isEmpty { sections.append("待复习：\(dueReviewPlans.count) 项") }
        if !completedChallenges.isEmpty { sections.append("完成挑战：\(completedChallenges.map(\.title).joined(separator: "、"))") }
        if let next = forgetting.first {
            sections.append("下一步推荐：温故“\(next.node.name)”")
        } else if let strongest = improvements.first, let node = nodeByID[strongest.0] {
            sections.append("下一步推荐：继续用实践巩固“\(node.name)”")
        }
        if sections.isEmpty { sections.append("今天尚无已验证学习结果。") }

        return DailyDigestSnapshot(
            date: day,
            summary: sections.joined(separator: "\n"),
            improvedNodeIDs: improvements.map(\.0),
            forgettingNodeIDs: forgetting.map { $0.node.id },
            xpEarned: xp
        )
    }
}
