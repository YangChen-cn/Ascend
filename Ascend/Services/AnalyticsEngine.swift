import Foundation

struct AnalyticsEngine: Sendable {
    func computeDomainProgress(
        nodes: [KnowledgeNode],
        masteryStates: [MasteryState],
        scoringEngine: ScoringEngine,
        now: Date = .now
    ) -> [DomainProgressSnapshot] {
        let masteryByNodeID = Dictionary(uniqueKeysWithValues: masteryStates.map { ($0.knowledgeNodeID, $0) })
        let grouped = Dictionary(grouping: nodes, by: \.domain)

        return grouped.map { domain, domainNodes in
            let states = domainNodes.compactMap { masteryByNodeID[$0.id] }
            let historicalScore = states.isEmpty ? 0 : states.reduce(0.0) { $0 + $1.composite } / Double(states.count)
            let currentScore = states.isEmpty ? 0 : states.reduce(0.0) { result, state in
                result + scoringEngine.projectDecay(
                    state.vector,
                    stabilityDays: state.stabilityDays,
                    lastEvidenceAt: state.lastEvidenceAt,
                    now: now
                ).composite
            } / Double(states.count)
            let xp = states.reduce(0) { $0 + $1.lifetimeXP }
            return DomainProgressSnapshot(
                name: domain,
                historicalScore: historicalScore,
                currentScore: currentScore,
                xp: xp,
                knowledgeCount: domainNodes.count,
                realm: DomainRealm.resolve(score: historicalScore, xp: xp),
                currentRealm: DomainRealm.resolve(score: currentScore, xp: xp)
            )
        }.sorted { lhs, rhs in
            lhs.xp == rhs.xp ? lhs.name < rhs.name : lhs.xp > rhs.xp
        }
    }

    func computeTodayMasteryChanges(
        nodes: [KnowledgeNode],
        ledgerEntries: [ScoreLedgerEntry],
        calendar: Calendar = .current
    ) -> [DashboardMetric] {
        let todayEntries = ledgerEntries.filter { calendar.isDateInToday($0.timestamp) }
        let nodeByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let grouped = Dictionary(grouping: todayEntries, by: \.knowledgeNodeID)

        return grouped.compactMap { nodeID, entries in
            guard let node = nodeByID[nodeID],
                  let first = entries.min(by: { $0.timestamp < $1.timestamp }),
                  let last = entries.max(by: { $0.timestamp < $1.timestamp }) else { return nil }
            return DashboardMetric(
                title: node.name,
                previous: Int(first.previousComposite.rounded()),
                current: Int(last.newComposite.rounded())
            )
        }.sorted { ($0.current - $0.previous) > ($1.current - $1.previous) }
    }

    func computeTodayXPGains(
        evidenceRecords: [EvidenceRecord],
        ledgerEntries: [ScoreLedgerEntry],
        calendar: Calendar = .current
    ) -> [XPGainItem] {
        let todayEntries = ledgerEntries.filter { calendar.isDateInToday($0.timestamp) }
        let evidenceByID = Dictionary(uniqueKeysWithValues: evidenceRecords.map { ($0.id, $0) })
        let grouped = Dictionary(grouping: todayEntries) { entry in
            evidenceByID[entry.evidenceID]?.kind ?? .exposure
        }
        return grouped.map { kind, entries in
            XPGainItem(
                title: kind.title,
                systemImage: icon(for: kind),
                xp: entries.reduce(0) { $0 + $1.xpAwarded }
            )
        }.sorted { $0.xp > $1.xp }
    }

    func computeForgettingProjections(
        nodes: [KnowledgeNode],
        masteryStates: [MasteryState],
        scoringEngine: ScoringEngine,
        now: Date = .now
    ) -> [ForgettingProjection] {
        let masteryByNodeID = Dictionary(uniqueKeysWithValues: masteryStates.map { ($0.knowledgeNodeID, $0) })

        return nodes.compactMap { node in
            guard let state = masteryByNodeID[node.id], state.lastEvidenceAt != nil else { return nil }
            let projected = scoringEngine.projectDecay(
                state.vector,
                stabilityDays: state.stabilityDays,
                lastEvidenceAt: state.lastEvidenceAt,
                now: now
            )
            let loss = Int((state.composite - projected.composite).rounded())
            guard loss > 0 else { return nil }
            return ForgettingProjection(node: node, scoreLoss: loss, retention: projected.retention)
        }.sorted { $0.scoreLoss > $1.scoreLoss }
    }

    private func icon(for kind: EvidenceKind) -> String {
        switch kind {
        case .exposure: "eye"
        case .explanation: "book"
        case .exercise: "checklist"
        case .project: "chevron.left.forwardslash.chevron.right"
        case .review: "arrow.clockwise"
        case .independentSolve: "target"
        }
    }
}
