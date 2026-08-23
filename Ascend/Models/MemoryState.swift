import Foundation
import SwiftData

@Model
final class MemoryState {
    @Attribute(.unique) var id: UUID
    var knowledgeNodeID: UUID
    var difficulty: Double
    var stability: Double
    var retrievability: Double
    var lastReviewAt: Date?
    var nextReviewAt: Date
    var scheduledDays: Double
    var reps: Int
    var lapses: Int
    var learningSteps: Int
    var learningStateRawValue: Int
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        knowledgeNodeID: UUID,
        difficulty: Double = 0,
        stability: Double = 0,
        retrievability: Double = 0,
        lastReviewAt: Date? = nil,
        nextReviewAt: Date = .now,
        scheduledDays: Double = 0,
        reps: Int = 0,
        lapses: Int = 0,
        learningSteps: Int = 0,
        learningState: MemoryLearningState = .new,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.knowledgeNodeID = knowledgeNodeID
        self.difficulty = difficulty
        self.stability = stability
        self.retrievability = retrievability
        self.lastReviewAt = lastReviewAt
        self.nextReviewAt = nextReviewAt
        self.scheduledDays = scheduledDays
        self.reps = reps
        self.lapses = lapses
        self.learningSteps = learningSteps
        self.learningStateRawValue = learningState.rawValue
        self.updatedAt = updatedAt
    }

    var learningState: MemoryLearningState {
        get { MemoryLearningState(rawValue: learningStateRawValue) ?? .new }
        set { learningStateRawValue = newValue.rawValue }
    }

    var schedulingState: MemorySchedulingState {
        MemorySchedulingState(
            difficulty: difficulty,
            stability: stability,
            lastReviewAt: lastReviewAt,
            nextReviewAt: nextReviewAt,
            scheduledDays: scheduledDays,
            reps: reps,
            lapses: lapses,
            learningSteps: learningSteps,
            learningState: learningState
        )
    }

    func update(from result: MemorySchedulingResult, at date: Date) {
        difficulty = result.state.difficulty
        stability = result.state.stability
        retrievability = result.retrievability
        lastReviewAt = result.state.lastReviewAt
        nextReviewAt = result.state.nextReviewAt
        scheduledDays = result.state.scheduledDays
        reps = result.state.reps
        lapses = result.state.lapses
        learningSteps = result.state.learningSteps
        learningStateRawValue = result.state.learningState.rawValue
        updatedAt = date
    }
}
