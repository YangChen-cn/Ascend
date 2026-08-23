import Foundation

enum MemoryLearningState: Int, Codable, Sendable {
    case new = 0
    case learning = 1
    case review = 2
    case relearning = 3
}
