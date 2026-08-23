import Foundation

enum MemoryReviewGrade: String, CaseIterable, Codable, Identifiable, Sendable {
    case again
    case hard
    case good
    case easy

    var id: Self { self }

    var title: String {
        switch self {
        case .again: "忘了"
        case .hard: "生疏"
        case .good: "记得"
        case .easy: "熟练"
        }
    }
}
