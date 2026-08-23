import Foundation

enum KnowledgeRelation: String, Codable, Sendable, CaseIterable {
    case prerequisite = "prerequisite"
    case related = "related"
    case partOf = "partOf"
    case contrasts = "contrasts"
    case applies = "applies"
    case derivedFrom = "derivedFrom"

    var title: String {
        switch self {
        case .prerequisite: "前置先导"
        case .related: "相关连结"
        case .partOf: "包含组成"
        case .contrasts: "对比辨析"
        case .applies: "实践应用"
        case .derivedFrom: "衍生拓展"
        }
    }

    var isDirectedPrerequisite: Bool {
        self == .prerequisite
    }

    static func from(rawValue: String) -> Self {
        if let exact = KnowledgeRelation(rawValue: rawValue) {
            return exact
        }
        let lower = rawValue.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lower.contains("前置") || lower.contains("先导") || lower.contains("先修") || lower.contains("prerequisite") {
            return .prerequisite
        }
        if lower.contains("组成") || lower.contains("包含") || lower.contains("partof") || lower.contains("part") {
            return .partOf
        }
        if lower.contains("对比") || lower.contains("区别") || lower.contains("辨析") || lower.contains("contrast") {
            return .contrasts
        }
        if lower.contains("应用") || lower.contains("实践") || lower.contains("applies") || lower.contains("apply") {
            return .applies
        }
        if lower.contains("衍生") || lower.contains("演化") || lower.contains("拓展") || lower.contains("derived") {
            return .derivedFrom
        }
        return .related
    }
}
