import Foundation

enum MasteryStage: String, CaseIterable, Codable, Sendable {
    case entry = "初窥"
    case advancing = "入门"
    case proficient = "通晓"
    case integrated = "融会"
    case connected = "化用"
    case mastered = "通达"

    static func stage(for score: Double) -> Self {
        switch score {
        case ..<20: .entry
        case ..<40: .advancing
        case ..<60: .proficient
        case ..<80: .integrated
        case ..<90: .connected
        default: .mastered
        }
    }

    var level: Int {
        switch self {
        case .entry: 1
        case .advancing: 2
        case .proficient: 3
        case .integrated: 4
        case .connected: 5
        case .mastered: 6
        }
    }

    var next: Self? {
        switch self {
        case .entry: .advancing
        case .advancing: .proficient
        case .proficient: .integrated
        case .integrated: .connected
        case .connected: .mastered
        case .mastered: nil
        }
    }

    var minimumScore: Int {
        switch self {
        case .entry: 0
        case .advancing: 20
        case .proficient: 40
        case .integrated: 60
        case .connected: 80
        case .mastered: 90
        }
    }
}
