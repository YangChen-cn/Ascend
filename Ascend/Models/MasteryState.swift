import Foundation
import SwiftData

@Model
final class MasteryState {
    @Attribute(.unique) var id: UUID
    var knowledgeNodeID: UUID
    var exposure: Double
    var understanding: Double
    var practice: Double
    var retention: Double
    var autonomy: Double
    var confidence: Double
    var stabilityDays: Double
    var lastEvidenceAt: Date?
    var lifetimeXP: Int
    var highestStageRawValue: String
    var peakComposite: Double = 0
    var artifactExposure: Double = 0
    var artifactUnderstanding: Double = 0
    var artifactPractice: Double = 0
    var artifactRetention: Double = 0
    var artifactAutonomy: Double = 0

    init(
        id: UUID = UUID(),
        knowledgeNodeID: UUID,
        vector: MasteryVector = .zero,
        confidence: Double = 0,
        stabilityDays: Double = 3,
        lastEvidenceAt: Date? = nil,
        lifetimeXP: Int = 0,
        highestStage: MasteryStage = .entry,
        peakComposite: Double? = nil,
        artifactVector: MasteryVector? = nil
    ) {
        self.id = id
        self.knowledgeNodeID = knowledgeNodeID
        self.exposure = vector.exposure
        self.understanding = vector.understanding
        self.practice = vector.practice
        self.retention = vector.retention
        self.autonomy = vector.autonomy
        self.confidence = confidence
        self.stabilityDays = stabilityDays
        self.lastEvidenceAt = lastEvidenceAt
        self.lifetimeXP = lifetimeXP
        self.highestStageRawValue = highestStage.rawValue
        self.peakComposite = peakComposite ?? vector.composite
        let initialArtifact = artifactVector ?? vector
        self.artifactExposure = initialArtifact.exposure
        self.artifactUnderstanding = initialArtifact.understanding
        self.artifactPractice = initialArtifact.practice
        self.artifactRetention = initialArtifact.retention
        self.artifactAutonomy = initialArtifact.autonomy
    }

    var vector: MasteryVector {
        get {
            MasteryVector(
                exposure: exposure,
                understanding: understanding,
                practice: practice,
                retention: retention,
                autonomy: autonomy
            )
        }
        set {
            exposure = newValue.exposure
            understanding = newValue.understanding
            practice = newValue.practice
            retention = newValue.retention
            autonomy = newValue.autonomy
        }
    }

    var composite: Double { vector.composite }

    var artifactVector: MasteryVector {
        get {
            MasteryVector(
                exposure: artifactExposure,
                understanding: artifactUnderstanding,
                practice: artifactPractice,
                retention: artifactRetention,
                autonomy: artifactAutonomy
            )
        }
        set {
            artifactExposure = newValue.exposure
            artifactUnderstanding = newValue.understanding
            artifactPractice = newValue.practice
            artifactRetention = newValue.retention
            artifactAutonomy = newValue.autonomy
        }
    }

    var stage: MasteryStage { MasteryStage.stage(for: composite) }

    var highestStage: MasteryStage {
        MasteryStage(rawValue: highestStageRawValue) ?? stage
    }
}
