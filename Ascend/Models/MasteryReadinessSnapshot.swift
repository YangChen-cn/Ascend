import Foundation

struct MasteryReadinessSnapshot: Sendable {
    let knowledgeNodeID: UUID
    let historicalVector: MasteryVector
    let currentVector: MasteryVector
    let historicalStage: MasteryStage
    let currentStage: MasteryStage

    var historicalComposite: Double { historicalVector.composite }
    var currentComposite: Double { currentVector.composite }
    var retention: Double { currentVector.retention }
}
