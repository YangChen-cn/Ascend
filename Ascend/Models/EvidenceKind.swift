import Foundation

enum EvidenceKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case exposure
    case explanation
    case exercise
    case project
    case review
    case independentSolve

    var id: Self { self }

    var title: String {
        switch self {
        case .exposure: "接触"
        case .explanation: "理解"
        case .exercise: "练习"
        case .project: "项目应用"
        case .review: "复习"
        case .independentSolve: "独立解决"
        }
    }

    var baseStrength: Double {
        switch self {
        case .exposure: 4
        case .explanation: 6
        case .exercise: 8
        case .project: 10
        case .review: 8
        case .independentSolve: 12
        }
    }
}
