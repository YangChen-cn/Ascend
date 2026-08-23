import Foundation
import FSRS

struct FSRSMemoryScheduler: MemoryScheduling {
    func review(
        state: MemorySchedulingState?,
        grade: MemoryReviewGrade,
        at date: Date,
        desiredRetention: Double
    ) throws -> MemorySchedulingResult {
        let scheduler = makeScheduler(desiredRetention: desiredRetention)
        let card = state.map(makeCard) ?? Card(due: date)
        let next = try scheduler.next(card: card, now: date, grade: makeRating(grade)).card
        return MemorySchedulingResult(
            state: makeState(next),
            retrievability: scheduler.getRetrievability(card: next, now: date).number.clamped(to: 0...1)
        )
    }

    func retrievability(
        state: MemorySchedulingState,
        at date: Date,
        desiredRetention: Double
    ) throws -> Double {
        makeScheduler(desiredRetention: desiredRetention)
            .getRetrievability(card: makeCard(state), now: date)
            .number
            .clamped(to: 0...1)
    }

    private func makeScheduler(desiredRetention: Double) -> FSRS {
        FSRS(
            parameters: FSRSParameters(
                requestRetention: desiredRetention.clamped(to: 0.7...0.97),
                w: FSRSDefaults.defaultWv6,
                enableFuzz: false,
                enableShortTerm: false
            )
        )
    }

    private func makeCard(_ state: MemorySchedulingState) -> Card {
        Card(
            due: state.nextReviewAt,
            stability: state.stability,
            difficulty: state.difficulty,
            scheduledDays: state.scheduledDays,
            learningSteps: state.learningSteps,
            reps: state.reps,
            lapses: state.lapses,
            state: CardState(rawValue: state.learningState.rawValue) ?? .new,
            lastReview: state.lastReviewAt
        )
    }

    private func makeState(_ card: Card) -> MemorySchedulingState {
        MemorySchedulingState(
            difficulty: card.difficulty,
            stability: card.stability,
            lastReviewAt: card.lastReview,
            nextReviewAt: card.due,
            scheduledDays: card.scheduledDays,
            reps: card.reps,
            lapses: card.lapses,
            learningSteps: card.learningSteps,
            learningState: MemoryLearningState(rawValue: card.state.rawValue) ?? .new
        )
    }

    private func makeRating(_ grade: MemoryReviewGrade) -> Rating {
        switch grade {
        case .again: .again
        case .hard: .hard
        case .good: .good
        case .easy: .easy
        }
    }
}
