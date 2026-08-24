import Foundation

enum ProductionPerformanceGrade: String, Codable, Sendable {
    case strong
    case weak
    case inconclusive
    case fail

    static func grade(for score: Double) -> ProductionPerformanceGrade {
        if score >= 0.85 {
            return .strong
        } else if score >= 0.70 {
            return .weak
        } else if score >= 0.50 {
            return .inconclusive
        } else {
            return .fail
        }
    }

    var isPassing: Bool {
        switch self {
        case .strong, .weak:
            return true
        case .inconclusive, .fail:
            return false
        }
    }

    var effectiveGuessProbability: Double {
        switch self {
        case .strong:
            return 0.01
        case .weak:
            return 0.05
        case .inconclusive:
            return 0.35
        case .fail:
            return 0.01
        }
    }

    var effectiveSlipProbability: Double {
        switch self {
        case .strong:
            return 0.05
        case .weak:
            return 0.20
        case .inconclusive:
            return 0.35
        case .fail:
            return 0.05
        }
    }
}
