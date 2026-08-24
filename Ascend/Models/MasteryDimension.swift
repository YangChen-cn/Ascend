import Foundation

enum MasteryDimension: String, CaseIterable, Codable, Identifiable, Sendable {
    case exposure
    case understanding
    case practice
    case retention
    case autonomy

    var id: Self { self }

    var title: String {
        switch self {
        case .exposure: "接触"
        case .understanding: "理解"
        case .practice: "实践"
        case .retention: "记忆"
        case .autonomy: "自主"
        }
    }
}
