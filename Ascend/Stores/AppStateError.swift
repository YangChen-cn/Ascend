import Foundation

enum AppStateError: LocalizedError {
    case missingEndpoint
    case missingModel
    case duplicateSource
    case invalidDomainName
    case missingDomain
    case missingKnowledgeNode
    case duplicateDomain
    case sameDomain
    case sourceSyncFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingEndpoint: "请先在设置中添加并选择一个 AI 接口"
        case .missingModel: "请先连接接口并选择模型"
        case .duplicateSource: "这个数据源已经添加"
        case .invalidDomainName: "领域名称不能为空"
        case .missingDomain: "找不到这个领域"
        case .missingKnowledgeNode: "找不到这个知识点"
        case .duplicateDomain: "已存在同名领域；如需归并，请使用合并操作"
        case .sameDomain: "来源领域和目标领域不能相同"
        case .sourceSyncFailed(let details): "数据源同步失败：\(details)"
        }
    }
}
