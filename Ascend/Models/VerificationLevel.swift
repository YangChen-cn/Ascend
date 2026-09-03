import Foundation

enum VerificationLevel: String, Codable, Sendable {
    case artifactCandidate
    case directChoice
    case productionRubric
    case productionDeterministic

    var isDirectPerformance: Bool {
        self != .artifactCandidate
    }

    var isProductionPerformance: Bool {
        self == .productionRubric || self == .productionDeterministic
    }
}
