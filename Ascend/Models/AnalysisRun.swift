import Foundation
import SwiftData

@Model
final class AnalysisRun {
    @Attribute(.unique) var id: UUID
    var endpointProfileID: UUID?
    var modelID: String
    var startedAt: Date
    var completedAt: Date?
    var status: String
    var activityCount: Int
    var errorMessage: String?

    init(
        id: UUID = UUID(),
        endpointProfileID: UUID?,
        modelID: String,
        startedAt: Date = .now,
        status: String = "running",
        activityCount: Int
    ) {
        self.id = id
        self.endpointProfileID = endpointProfileID
        self.modelID = modelID
        self.startedAt = startedAt
        self.status = status
        self.activityCount = activityCount
    }
}
