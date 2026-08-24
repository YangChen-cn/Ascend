import Foundation

struct ExportedAssessmentSummary: Codable, Sendable {
    let sessionID: UUID
    let knowledgeNodeID: UUID
    let kind: AssessmentKind
    let status: String
    let assistanceMode: AssistanceMode
    let startedAt: Date
    let completedAt: Date?
    let responses: [Response]
    let observations: [Observation]

    struct Response: Codable, Sendable {
        let itemID: UUID
        let selectedAnswerIndex: Int
        let selectedReasoningIndex: Int
        let answerIsCorrect: Bool
        let reasoningIsCorrect: Bool
        let answeredAt: Date
        let usedAssistance: Bool
        let isInvalidated: Bool
    }

    struct Observation: Codable, Sendable {
        let dimension: MasteryDimension
        let isCorrect: Bool
        let priorProbability: Double
        let predictedCorrectProbability: Double
        let posteriorProbability: Double
        let observedAt: Date
        let modelVersion: Int
        let isInvalidated: Bool
    }
}
