import Foundation

struct MasteryReadinessSnapshot: Sendable, Equatable {
    let knowledgeNodeID: UUID
    let historicalVector: MasteryVector
    let artifactFoundationVector: MasteryVector
    let currentVector: MasteryVector
    let historicalStage: MasteryStage
    let currentStage: MasteryStage
    let certifiedStage: MasteryStage
    let measurementStatus: MasteryMeasurementStatus
    let observationCount: Int
    let hasPassingDirectAssessment: Bool
    let lastMeasuredAt: Date?
    let stageBlockReason: String?
    let hasScheduledReview: Bool

    init(
        knowledgeNodeID: UUID,
        historicalVector: MasteryVector,
        artifactFoundationVector: MasteryVector = .zero,
        currentVector: MasteryVector,
        historicalStage: MasteryStage,
        currentStage: MasteryStage,
        certifiedStage: MasteryStage? = nil,
        measurementStatus: MasteryMeasurementStatus = .unmeasured,
        observationCount: Int = 0,
        hasPassingDirectAssessment: Bool = false,
        lastMeasuredAt: Date? = nil,
        stageBlockReason: String? = nil,
        hasScheduledReview: Bool = false
    ) {
        self.knowledgeNodeID = knowledgeNodeID
        self.historicalVector = historicalVector
        self.artifactFoundationVector = artifactFoundationVector
        self.currentVector = currentVector
        self.historicalStage = historicalStage
        self.currentStage = currentStage
        self.certifiedStage = certifiedStage ?? currentStage
        self.measurementStatus = measurementStatus
        self.observationCount = observationCount
        self.hasPassingDirectAssessment = hasPassingDirectAssessment
        self.lastMeasuredAt = lastMeasuredAt
        self.stageBlockReason = stageBlockReason
        self.hasScheduledReview = hasScheduledReview
    }

    var historicalComposite: Double { historicalVector.composite }
    var artifactFoundationComposite: Double { artifactFoundationVector.composite }
    var currentComposite: Double { currentVector.composite }
    var retention: Double { currentVector.retention }

    var isCertified: Bool {
        hasPassingDirectAssessment || certifiedStage.level >= MasteryStage.integrated.level
    }

    var verificationBadgeTitle: String {
        if isCertified {
            return "已印证"
        } else if observationCount > 0 {
            return "尚未通过"
        } else {
            return "待印证"
        }
    }

    var stageDisplayTitle: String {
        if isCertified {
            return "\(certifiedStage.rawValue) · 已印证"
        } else if observationCount > 0 {
            return "\(certifiedStage.rawValue) · 尚未通过"
        } else {
            return "\(certifiedStage.rawValue) · 待印证"
        }
    }
}
