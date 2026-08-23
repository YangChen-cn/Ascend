import Foundation
import SwiftData

@Model
final class RealmAdvancementEvent {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var evidenceID: UUID
    var knowledgeNodeID: UUID
    var previousStageRawValue: String
    var newStageRawValue: String
    var occurredAt: Date

    init(
        id: UUID = UUID(),
        evidenceID: UUID,
        knowledgeNodeID: UUID,
        previousStage: MasteryStage,
        newStage: MasteryStage,
        occurredAt: Date
    ) {
        self.id = id
        self.evidenceID = evidenceID
        self.knowledgeNodeID = knowledgeNodeID
        self.previousStageRawValue = previousStage.rawValue
        self.newStageRawValue = newStage.rawValue
        self.occurredAt = occurredAt
    }

    var previousStage: MasteryStage {
        MasteryStage(rawValue: previousStageRawValue) ?? .entry
    }

    var newStage: MasteryStage {
        MasteryStage(rawValue: newStageRawValue) ?? .entry
    }
}
