import Foundation

struct AssessmentPackage: Codable, Sendable {
    let knowledgeNodeID: UUID
    let items: [Item]

    struct Item: Codable, Identifiable, Sendable {
        let id: UUID
        let knowledgeNodeID: UUID
        let tier: AssessmentTier
        let stem: String
        let answerOptions: [String]
        let correctAnswerIndex: Int
        let reasoningPrompt: String
        let reasoningOptions: [String]
        let correctReasoningIndex: Int
        let explanation: String
        let misconceptionTags: [String]
        let sourceActivityIDs: [UUID]

        init(
            id: UUID = UUID(),
            knowledgeNodeID: UUID,
            tier: AssessmentTier,
            stem: String,
            answerOptions: [String],
            correctAnswerIndex: Int,
            reasoningPrompt: String,
            reasoningOptions: [String],
            correctReasoningIndex: Int,
            explanation: String,
            misconceptionTags: [String],
            sourceActivityIDs: [UUID]
        ) {
            self.id = id
            self.knowledgeNodeID = knowledgeNodeID
            self.tier = tier
            self.stem = stem
            self.answerOptions = answerOptions
            self.correctAnswerIndex = correctAnswerIndex
            self.reasoningPrompt = reasoningPrompt
            self.reasoningOptions = reasoningOptions
            self.correctReasoningIndex = correctReasoningIndex
            self.explanation = explanation
            self.misconceptionTags = misconceptionTags
            self.sourceActivityIDs = sourceActivityIDs
        }
    }
}
