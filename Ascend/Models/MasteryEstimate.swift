import Foundation
import SwiftData

@Model
final class MasteryEstimate {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var trackKey: String
    var knowledgeNodeID: UUID
    var dimensionRawValue: String
    var probability: Double
    var observationCount: Int
    var correctCount: Int
    var incorrectCount: Int
    var lastObservedAt: Date?
    var modelVersion: Int

    init(
        id: UUID = UUID(),
        knowledgeNodeID: UUID,
        dimension: MasteryDimension,
        probability: Double,
        observationCount: Int = 0,
        correctCount: Int = 0,
        incorrectCount: Int = 0,
        lastObservedAt: Date? = nil,
        modelVersion: Int
    ) {
        self.id = id
        self.trackKey = Self.key(nodeID: knowledgeNodeID, dimension: dimension)
        self.knowledgeNodeID = knowledgeNodeID
        self.dimensionRawValue = dimension.rawValue
        self.probability = probability
        self.observationCount = observationCount
        self.correctCount = correctCount
        self.incorrectCount = incorrectCount
        self.lastObservedAt = lastObservedAt
        self.modelVersion = modelVersion
    }

    var dimension: MasteryDimension {
        MasteryDimension(rawValue: dimensionRawValue) ?? .exposure
    }

    static func key(nodeID: UUID, dimension: MasteryDimension) -> String {
        "\(nodeID.uuidString):\(dimension.rawValue)"
    }
}
