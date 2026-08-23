import Foundation
import SwiftData

@Model
final class AutomationReceipt {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var key: String
    var kind: String
    var createdAt: Date

    init(id: UUID = UUID(), key: String, kind: String, createdAt: Date = .now) {
        self.id = id
        self.key = key
        self.kind = kind
        self.createdAt = createdAt
    }
}
