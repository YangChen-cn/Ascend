import Foundation

enum AssessmentKind: String, Codable, Sendable {
    case baseline
    case delayedReview
    case challenge
    case production
}
