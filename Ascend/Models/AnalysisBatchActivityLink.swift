import Foundation
import SwiftData

@Model
final class AnalysisBatchActivityLink {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var activityID: UUID
    var batchSummaryID: UUID
    var activityDate: Date

    init(
        id: UUID = UUID(),
        activityID: UUID,
        batchSummaryID: UUID,
        activityDate: Date
    ) {
        self.id = id
        self.activityID = activityID
        self.batchSummaryID = batchSummaryID
        self.activityDate = activityDate
    }
}
