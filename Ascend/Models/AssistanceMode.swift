import Foundation

enum AssistanceMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case unknown
    case declaredUnassisted
    case aiAssisted
    case aiDominant

    var id: Self { self }

    var title: String {
        switch self {
        case .unknown: "来源未知"
        case .declaredUnassisted: "声明独立完成"
        case .aiAssisted: "AI 辅助"
        case .aiDominant: "AI 主导"
        }
    }
}
