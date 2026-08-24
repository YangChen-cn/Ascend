import Foundation

struct AssessmentProgress: Sendable {
    let nextItemID: UUID?
    let isCompleted: Bool
    let requiresReviewGrade: Bool
}
