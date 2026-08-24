import Foundation

struct EmbeddedAssessmentPackage: Codable, Sendable {
    let domain: String
    let knowledgeNames: [String]
    let items: [Item]

    struct Item: Codable, Sendable {
        let id: UUID
        let knowledgeName: String
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
    }
}
