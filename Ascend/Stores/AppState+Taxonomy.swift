import Foundation
import SwiftData

extension AppState {
    func renameDomain(_ sourceName: String, to proposedName: String) throws {
        let targetName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetName.isEmpty else { throw AppStateError.invalidDomainName }
        let sourceNodes = nodes(inDomain: sourceName)
        guard !sourceNodes.isEmpty else { throw AppStateError.missingDomain }
        if sourceName == targetName {
            return
        }
        guard !domainNames.contains(where: {
            $0 != sourceName && $0.localizedStandardCompare(targetName) == .orderedSame
        }) else {
            throw AppStateError.duplicateDomain
        }
        sourceNodes.forEach {
            $0.domain = targetName
            $0.updatedAt = .now
        }
        try modelContext.save()
        updateSnapshots()
        statusMessage = "已将领域“\(sourceName)”重命名为“\(targetName)”"
    }

    func mergeDomain(_ sourceName: String, into targetName: String) throws {
        guard sourceName.localizedStandardCompare(targetName) != .orderedSame else {
            throw AppStateError.sameDomain
        }
        let sourceNodes = nodes(inDomain: sourceName)
        guard !sourceNodes.isEmpty else { throw AppStateError.missingDomain }
        guard let resolvedTarget = domainNames.first(where: {
            $0.localizedStandardCompare(targetName) == .orderedSame
        }) else {
            throw AppStateError.missingDomain
        }
        sourceNodes.forEach {
            $0.domain = resolvedTarget
            $0.updatedAt = .now
        }
        try modelContext.save()
        updateSnapshots()
        statusMessage = "已将领域“\(sourceName)”合并至“\(resolvedTarget)”"
    }

    func deleteDomain(_ domainName: String, strategy: DomainDeletionStrategy) throws {
        let domainNodes = nodes(inDomain: domainName)
        guard !domainNodes.isEmpty else { throw AppStateError.missingDomain }
        let successMessage: String

        switch strategy {
        case .moveKnowledgeToUncategorized:
            guard domainName.localizedStandardCompare("待分类") != .orderedSame else {
                throw AppStateError.sameDomain
            }
            domainNodes.forEach {
                $0.domain = "待分类"
                $0.updatedAt = .now
            }
            successMessage = "已删除领域“\(domainName)”，知识点已移至“待分类”"

        case .deleteKnowledge:
            let nodeIDs = Set(domainNodes.map(\.id))
            let removedEvidence = evidenceRecords.filter { nodeIDs.contains($0.knowledgeNodeID) }
            let removedEvidenceIDs = Set(removedEvidence.map(\.id))
            let affectedActivityIDs = Set(removedEvidence.map(\.activityID))
            let remainingEvidence = evidenceRecords.filter { !removedEvidenceIDs.contains($0.id) }

            knowledgeEdges
                .filter { nodeIDs.contains($0.sourceNodeID) || nodeIDs.contains($0.targetNodeID) }
                .forEach(modelContext.delete)
            scoreLedgerEntries
                .filter { nodeIDs.contains($0.knowledgeNodeID) || removedEvidenceIDs.contains($0.evidenceID) }
                .forEach(modelContext.delete)
            taxonomySuggestions
                .filter { $0.relatedNodeID.map(nodeIDs.contains) == true }
                .forEach(modelContext.delete)
            let removedChallenges = challenges.filter { !nodeIDs.isDisjoint(with: Set($0.knowledgeNodeIDs)) }
            let removedChallengeIDs = Set(removedChallenges.map(\.id))
            removedChallenges.forEach(modelContext.delete)
            challengeAutomationStates
                .filter { removedChallengeIDs.contains($0.challengeID) }
                .forEach(modelContext.delete)
            realmAdvancementEvents
                .filter { nodeIDs.contains($0.knowledgeNodeID) }
                .forEach(modelContext.delete)
            masteryStates
                .filter { nodeIDs.contains($0.knowledgeNodeID) }
                .forEach(modelContext.delete)
            reviewPlans
                .filter { nodeIDs.contains($0.knowledgeNodeID) }
                .forEach(modelContext.delete)
            memoryReviewEvents
                .filter { nodeIDs.contains($0.knowledgeNodeID) }
                .forEach(modelContext.delete)
            memoryStates
                .filter { nodeIDs.contains($0.knowledgeNodeID) }
                .forEach(modelContext.delete)
            removedEvidence.forEach(modelContext.delete)
            domainNodes.forEach(modelContext.delete)

            let remainingActivityIDs = Set(remainingEvidence.map(\.activityID))
            let orphanedActivityIDs = affectedActivityIDs.subtracting(remainingActivityIDs)
            let orphanedActivities = try fetchActivities(ids: orphanedActivityIDs)
            for activity in orphanedActivities {
                createTrackingExclusion(for: activity, reason: "永久删除领域“\(domainName)”")
                modelContext.delete(activity)
            }
            if selectedKnowledgeNodeID.map(nodeIDs.contains) == true {
                selectedKnowledgeNodeID = nil
            }
            successMessage = "已永久删除领域“\(domainName)”及其 \(domainNodes.count) 个知识点"
        }

        try modelContext.save()
        load()
        statusMessage = successMessage
    }

    private func processRelationApproval(_ suggestion: TaxonomySuggestion) -> (success: Bool, message: String) {
        guard let sourceID = suggestion.sourceNodeID,
              let targetID = suggestion.targetNodeID,
              let sourceNode = node(for: sourceID),
              let targetNode = node(for: targetID) else {
            return (false, "无法审核：关联的知识点已被删除")
        }

        guard sourceID != targetID else {
            return (false, "无法审核：先导依赖不能指向自身")
        }

        let relation = KnowledgeRelation.from(rawValue: suggestion.relationRawValue ?? "prerequisite")

        if relation == .prerequisite {
            let (canAdd, reason) = topologyEngine.canAddPrerequisite(
                sourceNodeID: sourceID,
                targetNodeID: targetID,
                existingEdges: knowledgeEdges
            )
            guard canAdd else {
                return (false, "无法审核：\(reason ?? "添加该先导依赖会导致循环依赖闭环")")
            }
        }

        let exists = knowledgeEdges.contains {
            $0.sourceNodeID == sourceID &&
            $0.targetNodeID == targetID &&
            $0.relation == relation
        }

        if !exists {
            let newEdge = KnowledgeEdge(
                sourceNodeID: sourceID,
                targetNodeID: targetID,
                relation: relation,
                confidence: suggestion.confidence,
                rationale: suggestion.rationale,
                origin: "userConfirmed",
                createdAt: suggestion.createdAt,
                confirmedAt: .now
            )
            modelContext.insert(newEdge)
            knowledgeEdges.append(newEdge)
        }

        return (true, "已确认知识脉络：\(sourceNode.name) → \(relation.title) → \(targetNode.name)")
    }

    private func processNextConceptApproval(_ suggestion: TaxonomySuggestion) -> (success: Bool, message: String) {
        let domain = suggestion.targetDomain ?? "通用"
        let nodeName = suggestion.proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nodeName.isEmpty else {
            return (false, "无法审核：知识点名称不能为空")
        }

        let existingNode = knowledgeNodes.first(where: { $0.name.localizedStandardCompare(nodeName) == .orderedSame })
        let targetID = existingNode?.id ?? UUID()

        // 1. 收集待建立的全部 prerequisite IDs
        var prereqIDs = suggestion.prerequisiteNodeIDs
        if prereqIDs.isEmpty, let singleSource = suggestion.sourceNodeID {
            prereqIDs.append(singleSource)
        }

        // 2. Preflight 校验：全部前置必须有效且满足 DAG 约束，任一失败则零提交
        var simulatedEdges = knowledgeEdges
        for prereqID in prereqIDs {
            guard let prereqNode = node(for: prereqID) else {
                return (false, "无法审核：前置知识点不存在或已被删除")
            }
            guard prereqID != targetID else {
                return (false, "无法审核：先导依赖不能指向自身")
            }

            let alreadyExists = simulatedEdges.contains {
                $0.sourceNodeID == prereqID &&
                $0.targetNodeID == targetID &&
                $0.relation == .prerequisite
            }
            if !alreadyExists {
                let (canAdd, reason) = topologyEngine.canAddPrerequisite(
                    sourceNodeID: prereqID,
                    targetNodeID: targetID,
                    existingEdges: simulatedEdges
                )
                guard canAdd else {
                    return (false, "无法审核：前置依赖“\(prereqNode.name)”到“\(nodeName)”\(reason ?? "会导致循环依赖闭环")")
                }
                let tempSimulatedEdge = KnowledgeEdge(
                    sourceNodeID: prereqID,
                    targetNodeID: targetID,
                    relation: .prerequisite,
                    confidence: suggestion.confidence
                )
                simulatedEdges.append(tempSimulatedEdge)
            }
        }

        // 3. Preflight 全部通过，一次性原子提交
        let targetNode: KnowledgeNode
        if let existing = existingNode {
            existing.isProvisional = false
            targetNode = existing
        } else {
            let newNode = KnowledgeNode(id: targetID, name: nodeName, domain: domain, isProvisional: false)
            modelContext.insert(newNode)
            knowledgeNodes.append(newNode)
            nodeByID[newNode.id] = newNode
            targetNode = newNode
        }

        // 确保存在对应 MasteryState(.zero)
        if mastery(for: targetNode.id) == nil {
            let initialMastery = MasteryState(
                knowledgeNodeID: targetNode.id,
                vector: .zero,
                confidence: 0,
                stabilityDays: 0,
                lastEvidenceAt: nil,
                lifetimeXP: 0,
                highestStage: .entry
            )
            modelContext.insert(initialMastery)
            masteryStates.append(initialMastery)
            masteryByNodeID[targetNode.id] = initialMastery
        }

        // 插入所有通过 preflight 的 KnowledgeEdge
        for prereqID in prereqIDs {
            let exists = knowledgeEdges.contains {
                $0.sourceNodeID == prereqID &&
                $0.targetNodeID == targetNode.id &&
                $0.relation == .prerequisite
            }
            guard !exists else { continue }

            let edge = KnowledgeEdge(
                sourceNodeID: prereqID,
                targetNodeID: targetNode.id,
                relation: .prerequisite,
                confidence: suggestion.confidence,
                rationale: suggestion.rationale,
                origin: "userConfirmed",
                createdAt: suggestion.createdAt,
                confirmedAt: .now
            )
            modelContext.insert(edge)
            knowledgeEdges.append(edge)
        }

        return (true, "已创建并收录下一境知识点“\(targetNode.name)”")
    }

    func evidence(for suggestion: TaxonomySuggestion) -> EvidenceRecord? {
        guard let evidenceID = suggestion.evidenceID else { return nil }
        return evidenceByID[evidenceID]
    }

    func approveSuggestion(_ suggestion: TaxonomySuggestion) {
        guard suggestion.status == "pending" else { return }
        if suggestion.suggestionType == "reviewEvidence" {
            guard let unverified = evidence(for: suggestion),
                  !unverified.isVerified,
                  node(for: unverified.knowledgeNodeID) != nil else {
                statusMessage = "无法审核：该建议缺少明确的证据关联，请重新分析对应活动"
                return
            }
            unverified.isVerified = true
            let xp = applyArtifactEvidence(unverified)
            statusMessage = xp > 0 ? "已确认材料归属，获得 \(xp) XP" : "已确认材料归属并计入成长"
        } else if suggestion.suggestionType == "newNode" {
            if let nodeID = suggestion.relatedNodeID, let node = node(for: nodeID) {
                node.isProvisional = false
                let relatedEvidence = evidenceRecords.filter { $0.knowledgeNodeID == node.id }
                for ev in relatedEvidence {
                    ev.isVerified = true
                    applyArtifactEvidence(ev)
                }
                statusMessage = "已收录知识点“\(node.name)”"
            }
        } else if suggestion.suggestionType == "relation" {
            let (success, message) = processRelationApproval(suggestion)
            statusMessage = message
            guard success else { return }
        } else if suggestion.suggestionType == "nextConcept" {
            let (success, message) = processNextConceptApproval(suggestion)
            statusMessage = message
            guard success else { return }
        }
        suggestion.status = "approved"
        try? modelContext.save()
        refreshDerivedState()
        runTriggerEngine()
    }

    func rejectSuggestion(_ suggestion: TaxonomySuggestion) {
        guard suggestion.status == "pending" else { return }
        if suggestion.suggestionType == "reviewEvidence" {
            guard let unverified = evidence(for: suggestion), !unverified.isVerified else {
                statusMessage = "无法忽略：该建议缺少明确的证据关联，请重新分析对应活动"
                return
            }
            modelContext.delete(unverified)
            evidenceRecords.removeAll { $0.id == unverified.id }
        } else if suggestion.suggestionType == "newNode" {
            if let nodeID = suggestion.relatedNodeID,
               let node = node(for: nodeID),
               !evidenceRecords.contains(where: { $0.knowledgeNodeID == nodeID && $0.isVerified }) {
                if let state = mastery(for: nodeID) {
                    modelContext.delete(state)
                    masteryStates.removeAll { $0.knowledgeNodeID == nodeID }
                }
                memoryReviewEvents
                    .filter { $0.knowledgeNodeID == nodeID }
                    .forEach(modelContext.delete)
                if let memory = memory(for: nodeID) {
                    modelContext.delete(memory)
                    memoryStates.removeAll { $0.id == memory.id }
                }
                modelContext.delete(node)
                knowledgeNodes.removeAll { $0.id == nodeID }
            }
        }
        suggestion.status = "rejected"
        statusMessage = "已忽略该建议"
        try? modelContext.save()
        refreshDerivedState()
    }

    func mergeSuggestion(_ suggestion: TaxonomySuggestion, into targetNodeID: UUID) {
        guard suggestion.status == "pending", let targetNode = node(for: targetNodeID) else { return }
        if suggestion.suggestionType == "reviewEvidence" {
            guard let unverified = evidence(for: suggestion), !unverified.isVerified else {
                statusMessage = "无法合并：该建议缺少明确的证据关联，请重新分析对应活动"
                return
            }
            unverified.knowledgeNodeID = targetNodeID
            unverified.isVerified = true
            applyArtifactEvidence(unverified)
            statusMessage = "已将材料归入“\(targetNode.name)”并计入研习成长"
        } else if suggestion.suggestionType == "newNode" {
            if let oldNodeID = suggestion.relatedNodeID {
                let relatedEvidence = evidenceRecords.filter { $0.knowledgeNodeID == oldNodeID }
                for ev in relatedEvidence {
                    ev.knowledgeNodeID = targetNodeID
                    ev.isVerified = true
                    applyArtifactEvidence(ev)
                }
                if let oldNode = node(for: oldNodeID) {
                    let targetKeys = Set(memoryReviewEvents.filter { $0.knowledgeNodeID == targetNodeID }.map(\.canonicalKey))
                    for event in memoryReviewEvents where event.knowledgeNodeID == oldNodeID {
                        if targetKeys.contains(event.canonicalKey) {
                            modelContext.delete(event)
                        } else {
                            event.knowledgeNodeID = targetNodeID
                        }
                    }
                    if let memory = memory(for: oldNodeID) {
                        modelContext.delete(memory)
                        memoryStates.removeAll { $0.id == memory.id }
                    }
                    if let state = mastery(for: oldNodeID) {
                        modelContext.delete(state)
                        masteryStates.removeAll { $0.knowledgeNodeID == oldNodeID }
                    }
                    modelContext.delete(oldNode)
                    knowledgeNodes.removeAll { $0.id == oldNodeID }
                    memoryReviewEvents.removeAll {
                        $0.knowledgeNodeID == oldNodeID && targetKeys.contains($0.canonicalKey)
                    }
                    replayMemory(nodeID: targetNodeID)
                }
                statusMessage = "已将“\(suggestion.proposedName)”合并至“\(targetNode.name)”"
            }
        }
        suggestion.status = "merged"
        try? modelContext.save()
        refreshDerivedState()
        runTriggerEngine()
    }

    func approveAllPendingSuggestions() {
        let pending = taxonomySuggestions.filter { $0.status == "pending" }
        guard !pending.isEmpty else { return }
        var approvedCount = 0
        for suggestion in pending {
            if suggestion.suggestionType == "reviewEvidence" {
                guard let unverified = evidence(for: suggestion),
                      !unverified.isVerified,
                      node(for: unverified.knowledgeNodeID) != nil else { continue }
                unverified.isVerified = true
            } else if suggestion.suggestionType == "newNode" {
                if let nodeID = suggestion.relatedNodeID, let node = node(for: nodeID) {
                    node.isProvisional = false
                }
            } else if suggestion.suggestionType == "relation" {
                let (success, _) = processRelationApproval(suggestion)
                guard success else { continue }
            } else if suggestion.suggestionType == "nextConcept" {
                let (success, _) = processNextConceptApproval(suggestion)
                guard success else { continue }
            }
            suggestion.status = "approved"
            approvedCount += 1
        }
        statusMessage = approvedCount == pending.count
            ? "已批量确认 \(approvedCount) 条待审核建议"
            : "已确认 \(approvedCount) 条；另有 \(pending.count - approvedCount) 条因校验未通过未能确认"
        try? modelContext.save()
        refreshDerivedState()
        runTriggerEngine()
    }
}
