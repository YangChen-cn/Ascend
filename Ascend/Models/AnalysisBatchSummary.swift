import Foundation
import SwiftData

@Model
final class AnalysisBatchSummary {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var analysisRunID: UUID
    var date: Date
    var summary: String

    init(
        id: UUID = UUID(),
        analysisRunID: UUID,
        date: Date = .now,
        summary: String
    ) {
        self.id = id
        self.analysisRunID = analysisRunID
        self.date = date
        self.summary = summary
    }
}
