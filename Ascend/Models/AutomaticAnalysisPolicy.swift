import Foundation

enum AutomaticAnalysisPolicy: String, CaseIterable, Identifiable, Codable, Sendable {
    case off
    case daily
    case pendingThreshold

    var id: Self { self }

    var title: String {
        switch self {
        case .off: "关闭"
        case .daily: "每天一次"
        case .pendingThreshold: "待分析达到阈值"
        }
    }
}
