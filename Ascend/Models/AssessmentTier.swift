import Foundation

enum AssessmentTier: String, CaseIterable, Codable, Identifiable, Sendable {
    case foundational
    case application
    case transfer

    var id: Self { self }

    var title: String {
        switch self {
        case .foundational: "基础辨析"
        case .application: "情境应用"
        case .transfer: "迁移调试"
        }
    }

    var level: Int {
        switch self {
        case .foundational: 0
        case .application: 1
        case .transfer: 2
        }
    }

    var primaryDimension: MasteryDimension {
        switch self {
        case .foundational: .exposure
        case .application: .practice
        case .transfer: .autonomy
        }
    }
}
