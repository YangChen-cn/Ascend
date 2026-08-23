import Foundation

struct ScoringResult: Equatable, Sendable {
    let previous: MasteryVector
    let updated: MasteryVector
    let xpAwarded: Int
    let stabilityDays: Double

    var previousComposite: Double { previous.composite }
    var newComposite: Double { updated.composite }
    var stage: MasteryStage { MasteryStage.stage(for: newComposite) }
}
