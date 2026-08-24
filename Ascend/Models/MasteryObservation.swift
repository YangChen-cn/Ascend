import Foundation
import SwiftData

@Model
final class MasteryObservation {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var canonicalKey: String
    var sessionID: UUID
    var itemID: UUID
    var responseID: UUID
    var knowledgeNodeID: UUID
    var dimensionRawValue: String
    var isCorrect: Bool
    var guessProbability: Double
    var slipProbability: Double
    var priorProbability: Double
    var predictedCorrectProbability: Double
    var posteriorProbability: Double
    var observedAt: Date
    var modelVersion: Int
    var isInvalidated: Bool

    init(
        id: UUID = UUID(),
        canonicalKey: String,
        sessionID: UUID,
        itemID: UUID,
        responseID: UUID,
        knowledgeNodeID: UUID,
        dimension: MasteryDimension,
        isCorrect: Bool,
        guessProbability: Double,
        slipProbability: Double,
        priorProbability: Double,
        predictedCorrectProbability: Double,
        posteriorProbability: Double,
        observedAt: Date,
        modelVersion: Int
    ) {
        self.id = id
        self.canonicalKey = canonicalKey
        self.sessionID = sessionID
        self.itemID = itemID
        self.responseID = responseID
        self.knowledgeNodeID = knowledgeNodeID
        self.dimensionRawValue = dimension.rawValue
        self.isCorrect = isCorrect
        self.guessProbability = guessProbability
        self.slipProbability = slipProbability
        self.priorProbability = priorProbability
        self.predictedCorrectProbability = predictedCorrectProbability
        self.posteriorProbability = posteriorProbability
        self.observedAt = observedAt
        self.modelVersion = modelVersion
        self.isInvalidated = false
    }

    var dimension: MasteryDimension {
        MasteryDimension(rawValue: dimensionRawValue) ?? .exposure
    }
}
