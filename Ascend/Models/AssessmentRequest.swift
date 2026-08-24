import Foundation

struct AssessmentRequest: Codable, Sendable {
    let knowledgeNodeID: UUID
    let knowledgeName: String
    let domain: String
    let currentMasteryProbability: Double?
    let kind: AssessmentKind
    let sourceMaterials: [SourceMaterial]
    let targetKnowledgeNodes: [TargetKnowledgeNode]

    init(
        knowledgeNodeID: UUID,
        knowledgeName: String,
        domain: String,
        currentMasteryProbability: Double?,
        kind: AssessmentKind,
        sourceMaterials: [SourceMaterial],
        targetKnowledgeNodes: [TargetKnowledgeNode]? = nil
    ) {
        self.knowledgeNodeID = knowledgeNodeID
        self.knowledgeName = knowledgeName
        self.domain = domain
        self.currentMasteryProbability = currentMasteryProbability
        self.kind = kind
        self.sourceMaterials = sourceMaterials
        self.targetKnowledgeNodes = targetKnowledgeNodes ?? [
            TargetKnowledgeNode(
                knowledgeNodeID: knowledgeNodeID,
                knowledgeName: knowledgeName,
                currentMasteryProbability: currentMasteryProbability
            )
        ]
    }

    struct TargetKnowledgeNode: Codable, Sendable {
        let knowledgeNodeID: UUID
        let knowledgeName: String
        let currentMasteryProbability: Double?
        let preferredTier: AssessmentTier?

        init(
            knowledgeNodeID: UUID,
            knowledgeName: String,
            currentMasteryProbability: Double?,
            preferredTier: AssessmentTier? = nil
        ) {
            self.knowledgeNodeID = knowledgeNodeID
            self.knowledgeName = knowledgeName
            self.currentMasteryProbability = currentMasteryProbability
            self.preferredTier = preferredTier
        }
    }

    struct SourceMaterial: Codable, Sendable {
        let activityID: UUID
        let title: String
        let summary: String
        let excerpt: String
    }
}
