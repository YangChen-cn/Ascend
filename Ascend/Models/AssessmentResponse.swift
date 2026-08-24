import Foundation
import SwiftData

@Model
final class AssessmentResponse {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var itemID: UUID
    var sessionID: UUID
    var knowledgeNodeID: UUID
    var selectedAnswerIndex: Int
    var selectedReasoningIndex: Int
    var answerIsCorrect: Bool
    var reasoningIsCorrect: Bool
    var answeredAt: Date
    var usedAssistance: Bool
    var isInvalidated: Bool

    init(
        id: UUID = UUID(),
        item: AssessmentItem,
        selectedAnswerIndex: Int,
        selectedReasoningIndex: Int,
        usedAssistance: Bool,
        answeredAt: Date = .now
    ) {
        self.id = id
        self.itemID = item.id
        self.sessionID = item.sessionID
        self.knowledgeNodeID = item.knowledgeNodeID
        self.selectedAnswerIndex = selectedAnswerIndex
        self.selectedReasoningIndex = selectedReasoningIndex
        self.answerIsCorrect = selectedAnswerIndex == item.correctAnswerIndex
        self.reasoningIsCorrect = selectedReasoningIndex == item.correctReasoningIndex
        self.answeredAt = answeredAt
        self.usedAssistance = usedAssistance
        self.isInvalidated = false
    }

    var isFullyCorrect: Bool { answerIsCorrect && reasoningIsCorrect }
    var wasSkipped: Bool { selectedAnswerIndex < 0 || selectedReasoningIndex < 0 }
}
