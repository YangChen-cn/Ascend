import Foundation
import SwiftData

@Model
final class KnowledgeEdge {
    @Attribute(.unique) var id: UUID
    var sourceNodeID: UUID
    var targetNodeID: UUID
    var relationRawValue: String
    var confidence: Double

    init(
        id: UUID = UUID(),
        sourceNodeID: UUID,
        targetNodeID: UUID,
        relationRawValue: String,
        confidence: Double
    ) {
        self.id = id
        self.sourceNodeID = sourceNodeID
        self.targetNodeID = targetNodeID
        self.relationRawValue = relationRawValue
        self.confidence = confidence
    }
}
