import Foundation

enum AppStateError: LocalizedError {
    case missingEndpoint
    case missingModel
    case duplicateSource

    var errorDescription: String? {
        switch self {
        case .missingEndpoint: "请先在设置中添加并选择一个 AI 接口"
        case .missingModel: "请先连接接口并选择模型"
        case .duplicateSource: "这个数据源已经添加"
        }
    }
}
