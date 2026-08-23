import Foundation

struct MemorySchedulingResult: Equatable, Sendable {
    let state: MemorySchedulingState
    let retrievability: Double
}
