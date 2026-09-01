import Foundation

enum AssessmentPackagePolicy {
    enum ValidationError: LocalizedError, Equatable {
        case wrongNode
        case insufficientValidItems(Int)

        var errorDescription: String? {
            switch self {
            case .wrongNode: "测评题包与目标知识点不一致"
            case .insufficientValidItems(let count): "测评题包仅有 \(count) 道有效题，至少需要 3 道"
            }
        }
    }

    static func validated(
        _ package: AssessmentPackage,
        request: AssessmentRequest,
        minimumItemCount: Int = 3
    ) throws -> AssessmentPackage {
        guard package.knowledgeNodeID == request.knowledgeNodeID else {
            throw ValidationError.wrongNode
        }
        let allowedActivityIDs = Set(request.sourceMaterials.map(\.activityID))
        let allowedNodeIDs = Set(request.targetKnowledgeNodes.map(\.knowledgeNodeID))
        var fingerprints = Set<String>()
        var itemIDs = Set<UUID>()
        let validItems = package.items.filter { item in
            let stem = item.stem.trimmingCharacters(in: .whitespacesAndNewlines)
            let reasoningPrompt = item.reasoningPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !stem.isEmpty,
                  !reasoningPrompt.isEmpty,
                  !containsAnswerLeakage(stem),
                  !containsAnswerLeakage(reasoningPrompt),
                  item.answerOptions.count == 4,
                  item.reasoningOptions.count == 4,
                  item.answerOptions.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
                  item.reasoningOptions.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
                  Set(item.answerOptions.map(normalize)).count == 4,
                  Set(item.reasoningOptions.map(normalize)).count == 4,
                  item.answerOptions.indices.contains(item.correctAnswerIndex),
                  item.reasoningOptions.indices.contains(item.correctReasoningIndex),
                  !item.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  allowedNodeIDs.contains(item.knowledgeNodeID),
                  Set(item.sourceActivityIDs).isSubset(of: allowedActivityIDs) else {
                return false
            }
            let fingerprint = normalize(stem) + "|" + normalize(reasoningPrompt)
            return fingerprints.insert(fingerprint).inserted && itemIDs.insert(item.id).inserted
        }
        guard validItems.count >= minimumItemCount else {
            throw ValidationError.insufficientValidItems(validItems.count)
        }
        let selectedItems = Array(validItems.prefix(6))
        guard Set(selectedItems.map(\.knowledgeNodeID)).isSuperset(of: allowedNodeIDs) else {
            throw ValidationError.insufficientValidItems(validItems.count)
        }
        guard Set(selectedItems.map(\.tier)).isSuperset(of: AssessmentTier.allCases) else {
            throw ValidationError.insufficientValidItems(validItems.count)
        }
        return AssessmentPackage(knowledgeNodeID: package.knowledgeNodeID, items: selectedItems)
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func containsAnswerLeakage(_ value: String) -> Bool {
        let normalized = normalize(value)
        return ["正确答案", "答案是", "correct answer", "correct option"].contains {
            normalized.contains($0)
        }
    }
}
