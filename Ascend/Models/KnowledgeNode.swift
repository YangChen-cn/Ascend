import Foundation
import SwiftData

@Model
final class KnowledgeNode {
    @Attribute(.unique) var id: UUID
    var name: String
    var domain: String
    var parentID: UUID?
    var isProvisional: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        domain: String,
        parentID: UUID? = nil,
        isProvisional: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.domain = domain
        self.parentID = parentID
        self.isProvisional = isProvisional
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}
