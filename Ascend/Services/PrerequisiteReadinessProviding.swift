import Foundation

enum PrerequisiteReadiness: Sendable {
    case ready
    case blocked(reason: String)
    case unknown
}

protocol PrerequisiteReadinessProviding: Sendable {
    func readiness(for knowledgeNodeID: UUID) -> PrerequisiteReadiness
}
