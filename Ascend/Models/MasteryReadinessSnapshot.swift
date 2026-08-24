import Foundation

struct MasteryReadinessSnapshot: Sendable {
    let knowledgeNodeID: UUID
    let historicalVector: MasteryVector
    let currentVector: MasteryVector
    let historicalStage: MasteryStage
    let currentStage: MasteryStage
    let certifiedStage: MasteryStage
    let measurementStatus: MasteryMeasurementStatus
    let observationCount: Int
    let lastMeasuredAt: Date?
    let stageBlockReason: String?

    init(
        knowledgeNodeID: UUID,
        historicalVector: MasteryVector,
        currentVector: MasteryVector,
        historicalStage: MasteryStage,
        currentStage: MasteryStage,
        certifiedStage: MasteryStage? = nil,
        measurementStatus: MasteryMeasurementStatus = .unmeasured,
        observationCount: Int = 0,
        lastMeasuredAt: Date? = nil,
        stageBlockReason: String? = nil
    ) {
        self.knowledgeNodeID = knowledgeNodeID
        self.historicalVector = historicalVector
        self.currentVector = currentVector
        self.historicalStage = historicalStage
        self.currentStage = currentStage
        self.certifiedStage = certifiedStage ?? currentStage
        self.measurementStatus = measurementStatus
        self.observationCount = observationCount
        self.lastMeasuredAt = lastMeasuredAt
        self.stageBlockReason = stageBlockReason
    }

    var historicalComposite: Double { historicalVector.composite }
    var currentComposite: Double { currentVector.composite }
    var retention: Double { currentVector.retention }
}
