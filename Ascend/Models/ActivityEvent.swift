import Foundation
import SwiftData

@Model
final class ActivityEvent {
    @Attribute(.unique) var id: UUID
    var sourceID: UUID
    var sourceKindRawValue: String
    var timestamp: Date
    var fingerprint: String
    var title: String
    var sourceLocator: String
    var summary: String
    var excerpt: String
    var isProcessed: Bool

    init(
        id: UUID = UUID(),
        sourceID: UUID,
        sourceKind: SourceKind,
        timestamp: Date,
        fingerprint: String,
        title: String,
        sourceLocator: String,
        summary: String,
        excerpt: String,
        isProcessed: Bool = false
    ) {
        self.id = id
        self.sourceID = sourceID
        self.sourceKindRawValue = sourceKind.rawValue
        self.timestamp = timestamp
        self.fingerprint = fingerprint
        self.title = title
        self.sourceLocator = sourceLocator
        self.summary = summary
        self.excerpt = String(excerpt.prefix(AppConstants.maximumAuditExcerptLength))
        self.isProcessed = isProcessed
    }
}
