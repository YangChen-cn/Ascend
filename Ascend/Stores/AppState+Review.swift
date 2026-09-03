import Foundation
import SwiftData

extension AppState {
    private static let reviewMetaFilterPatterns = [
        "完成验证", "已分析", "已收录", "已纳管", "验证题包", "研习实据", "测试", "无摘要", "待分析"
    ]

    private func isContentRichSummary(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        for pattern in Self.reviewMetaFilterPatterns {
            if trimmed == pattern || (trimmed.count < 10 && trimmed.contains(pattern)) {
                return false
            }
        }
        return true
    }

    private func evidenceContentPriority(_ kind: EvidenceKind) -> Int {
        switch kind {
        case .explanation: 1
        case .project: 2
        case .independentSolve: 3
        case .exercise: 4
        case .review: 5
        case .exposure: 6
        }
    }

    /// 从本地已有数据中提取 2～5 条知识点要点与研习摘要（零 AI 调用，仅使用已确认的真实证据）
    func reviewKeyPoints(for nodeID: UUID) -> [String] {
        var points: [String] = []

        // 1. 只使用已确认的 (isVerified == true) 证据，并按内容价值高低排序
        let evidences = evidenceRecords(for: nodeID)
            .filter { $0.isVerified && ($0.origin == .artifact || $0.origin == .legacy) }
            .sorted { (lhs, rhs) -> Bool in
                let pL = evidenceContentPriority(lhs.kind)
                let pR = evidenceContentPriority(rhs.kind)
                if pL != pR {
                    return pL < pR
                }
                return lhs.timestamp > rhs.timestamp
            }

        for ev in evidences {
            let summary = ev.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            if isContentRichSummary(summary) && !points.contains(summary) {
                points.append(summary)
            }
            let rationale = ev.rationale.trimmingCharacters(in: .whitespacesAndNewlines)
            if points.count < 4, isContentRichSummary(rationale), !points.contains(rationale) {
                points.append(rationale)
            }
            if points.count >= 4 { break }
        }

        // 2. 如果要点不足，尝试结合已验证证据关联的 Activity 摘要/标题
        if points.count < 3 {
            let activityIDs = Set(evidences.map(\.activityID))
            let linkedActivities = (try? fetchActivities(ids: activityIDs)) ?? []
            for act in linkedActivities
                .filter(ReviewActivityLocator.isMarkdownNote)
                .sorted(by: { $0.timestamp > $1.timestamp }) {
                let summary = act.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                if isContentRichSummary(summary) && !points.contains(summary) {
                    points.append(summary)
                } else if isContentRichSummary(act.title) && !points.contains(act.title) {
                    points.append(act.title)
                }
                if points.count >= 4 { break }
            }
        }

        // 3. 如果依然不足，提供保底提示
        if points.isEmpty, let node = node(for: nodeID) {
            points.append("围绕“\(node.name)”回忆：核心作用、关键机制、边界条件，以及一个亲手实践过的例子。")
        }

        return Array(points.prefix(5))
    }

    /// 提取该知识点最近关联的学习与代码来源（零 AI 调用，仅取已确认实据关联活动）
    func linkedActivities(for nodeID: UUID) -> [ActivityEvent] {
        let verifiedEvidences = evidenceRecords(for: nodeID)
            .filter(\.isVerified)
            .sorted { $0.timestamp > $1.timestamp }
        let activityIDs = Set(verifiedEvidences.map(\.activityID))
        guard let linked = try? fetchActivities(ids: activityIDs) else { return [] }
        return linked.sorted(by: { $0.timestamp > $1.timestamp })
    }

    /// 提取该知识点最近关联的学习与代码来源（零 AI 调用）
    func reviewSources(for nodeID: UUID) -> [String] {
        let verifiedEvidences = evidenceRecords(for: nodeID)
            .filter(\.isVerified)
            .sorted { $0.timestamp > $1.timestamp }
        let activityIDs = Set(verifiedEvidences.map(\.activityID))
        guard let linkedActivities = try? fetchActivities(ids: activityIDs) else { return [] }

        var sources: [String] = []
        for act in linkedActivities.sorted(by: { $0.timestamp > $1.timestamp }) {
            let locator = act.sourceLocator.trimmingCharacters(in: .whitespacesAndNewlines)
            let displaySource: String
            if !locator.isEmpty {
                displaySource = "\(act.sourceKind.title)：\(locator)"
            } else {
                displaySource = "\(act.sourceKind.title)：\(act.title)"
            }
            if !sources.contains(displaySource) {
                sources.append(displaySource)
            }
            if sources.count >= 3 { break }
        }
        return sources
    }

    /// 完成一次知识卡温故自评（完全在本地运行，零 AI 调用，仅更新 FSRS 记忆与排期，不伪造 mastery 测验）
    func completeCardReview(
        for plan: ReviewPlan,
        grade: MemoryReviewGrade,
        at date: Date = .now
    ) throws {
        guard plan.status == "due" || plan.status == "scheduled" else { return }
        guard let node = node(for: plan.knowledgeNodeID) else {
            throw AppStateError.missingKnowledgeNode
        }

        let canonicalKey = "cardReview:\(plan.id.uuidString)"
        if !memoryReviewEvents.contains(where: { $0.canonicalKey == canonicalKey }) {
            let event = MemoryReviewEvent(
                knowledgeNodeID: plan.knowledgeNodeID,
                evidenceID: nil,
                canonicalKey: canonicalKey,
                grade: grade,
                reviewedAt: date,
                source: "cardReview"
            )
            modelContext.insert(event)
            memoryReviewEvents.append(event)
        }

        // 触发 FSRS 重放，更新 MemoryState
        replayMemory(nodeID: plan.knowledgeNodeID)

        // 完成当前复习计划
        plan.status = "completed"

        // 为下一次到期排期新的 ReviewPlan（避免重复创建已有活动计划）
        if let memory = memoryByNodeID[plan.knowledgeNodeID] {
            let nextReviewAt = memory.nextReviewAt
            let hasActivePlan = reviewPlans.contains(where: {
                $0.id != plan.id &&
                $0.knowledgeNodeID == plan.knowledgeNodeID &&
                ($0.status == "scheduled" || $0.status == "due")
            })
            if !hasActivePlan {
                let nextPlan = ReviewPlan(
                    knowledgeNodeID: plan.knowledgeNodeID,
                    scheduledAt: nextReviewAt,
                    reason: "FSRS 到期温故",
                    status: nextReviewAt <= date ? "due" : "scheduled"
                )
                modelContext.insert(nextPlan)
                reviewPlans.insert(nextPlan, at: 0)
            }
        }

        try modelContext.save()
        refreshDerivedState()
        statusMessage = "“\(node.name)”温故完成（\(grade.title)）"
    }

    /// 针对特定知识点进行直接主动温故（若该知识点尚无活跃计划，自动关联并排期）
    func completeDirectCardReview(
        for nodeID: UUID,
        grade: MemoryReviewGrade,
        at date: Date = .now
    ) throws {
        if let activePlan = reviewPlans.first(where: {
            $0.knowledgeNodeID == nodeID && ($0.status == "due" || $0.status == "scheduled")
        }) {
            try completeCardReview(for: activePlan, grade: grade, at: date)
            return
        }

        guard let node = node(for: nodeID) else {
            throw AppStateError.missingKnowledgeNode
        }

        let canonicalKey = "cardReview:\(nodeID.uuidString):\(date.timeIntervalSince1970)"
        let event = MemoryReviewEvent(
            knowledgeNodeID: nodeID,
            evidenceID: nil,
            canonicalKey: canonicalKey,
            grade: grade,
            reviewedAt: date,
            source: "cardReview"
        )
        modelContext.insert(event)
        memoryReviewEvents.append(event)

        replayMemory(nodeID: nodeID)

        if let memory = memoryByNodeID[nodeID] {
            let nextReviewAt = memory.nextReviewAt
            let nextPlan = ReviewPlan(
                knowledgeNodeID: nodeID,
                scheduledAt: nextReviewAt,
                reason: "FSRS 到期温故",
                status: nextReviewAt <= date ? "due" : "scheduled"
            )
            modelContext.insert(nextPlan)
            reviewPlans.insert(nextPlan, at: 0)
        }

        try modelContext.save()
        refreshDerivedState()
        statusMessage = "“\(node.name)”温故完成（\(grade.title)）"
    }
}
