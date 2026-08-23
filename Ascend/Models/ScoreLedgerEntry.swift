import Foundation
import SwiftData

@Model
final class ScoreLedgerEntry {
    @Attribute(.unique) var id: UUID
    var evidenceID: UUID
    var knowledgeNodeID: UUID
    var timestamp: Date
    var previousComposite: Double
    var newComposite: Double
    var xpAwarded: Int
    var reason: String

    init(
        id: UUID = UUID(),
        evidenceID: UUID,
        knowledgeNodeID: UUID,
        timestamp: Date,
        previousComposite: Double,
        newComposite: Double,
        xpAwarded: Int,
        reason: String
    ) {
        self.id = id
        self.evidenceID = evidenceID
        self.knowledgeNodeID = knowledgeNodeID
        self.timestamp = timestamp
        self.previousComposite = previousComposite
        self.newComposite = newComposite
        self.xpAwarded = xpAwarded
        self.reason = reason
    }
}
