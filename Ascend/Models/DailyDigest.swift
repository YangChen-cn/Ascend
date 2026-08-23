import Foundation
import SwiftData

@Model
final class DailyDigest {
    @Attribute(.unique) var id: UUID
    var date: Date
    var summary: String
    var improvedNodeIDsJSON: String
    var forgettingNodeIDsJSON: String
    var xpEarned: Int
    var generatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        summary: String,
        improvedNodeIDsJSON: String = "[]",
        forgettingNodeIDsJSON: String = "[]",
        xpEarned: Int,
        generatedAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.summary = summary
        self.improvedNodeIDsJSON = improvedNodeIDsJSON
        self.forgettingNodeIDsJSON = forgettingNodeIDsJSON
        self.xpEarned = xpEarned
        self.generatedAt = generatedAt
    }
}
