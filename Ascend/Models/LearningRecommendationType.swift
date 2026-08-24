import Foundation

enum LearningRecommendationType: String, Codable, Sendable {
    case review
    case practice
    case challenge
    case nextConcept
    case `continue`

    var title: String {
        switch self {
        case .review: "复习"
        case .practice: "补弱"
        case .challenge: "试炼"
        case .nextConcept: "下一境"
        case .continue: "延续"
        }
    }
}
