import Foundation

protocol MemoryScheduling: Sendable {
    func review(
        state: MemorySchedulingState?,
        grade: MemoryReviewGrade,
        at date: Date,
        desiredRetention: Double
    ) throws -> MemorySchedulingResult

    func retrievability(
        state: MemorySchedulingState,
        at date: Date,
        desiredRetention: Double
    ) throws -> Double
}
