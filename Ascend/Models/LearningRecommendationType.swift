import Foundation

enum LearningRecommendationType: String, Codable, Sendable {
    case review
    case practice
    case challenge
    case `continue`

    var title: String {
        switch self {
        case .review: "温故"
        case .practice: "补弱"
        case .challenge: "试炼"
        case .continue: "延续"
        }
    }
}
