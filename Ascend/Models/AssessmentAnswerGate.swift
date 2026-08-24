import Foundation

struct AssessmentAnswerGate: Sendable, Equatable {
    private(set) var firstSelectedIndex: Int?
    private(set) var isReasoningUnlocked = false

    @discardableResult
    mutating func submitAnswer(_ selectedIndex: Int, correctIndex: Int) -> Bool {
        if firstSelectedIndex == nil {
            firstSelectedIndex = selectedIndex
        }
        isReasoningUnlocked = selectedIndex == correctIndex
        return isReasoningUnlocked
    }
}
