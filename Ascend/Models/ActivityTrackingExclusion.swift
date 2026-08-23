import Foundation
import SwiftData

@Model
final class ActivityTrackingExclusion {
    @Attribute(.unique) var id: UUID
    var sourceID: UUID
    var sourceKindRawValue: String
    var sourceLocator: String
    var createdAt: Date
    var reason: String

    init(
        id: UUID = UUID(),
        sourceID: UUID,
        sourceKind: SourceKind,
        sourceLocator: String,
        createdAt: Date = .now,
        reason: String
    ) {
        self.id = id
        self.sourceID = sourceID
        self.sourceKindRawValue = sourceKind.rawValue
        self.sourceLocator = sourceLocator
        self.createdAt = createdAt
        self.reason = reason
    }
}
