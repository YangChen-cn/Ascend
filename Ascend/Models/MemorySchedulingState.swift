import Foundation

struct MemorySchedulingState: Equatable, Sendable {
    let difficulty: Double
    let stability: Double
    let lastReviewAt: Date?
    let nextReviewAt: Date
    let scheduledDays: Double
    let reps: Int
    let lapses: Int
    let learningSteps: Int
    let learningState: MemoryLearningState
}
