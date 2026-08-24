import Foundation

enum AssessmentGenerationError: LocalizedError {
    case unsupported
    case batchFormatIncompatible(String)

    var errorDescription: String? {
        switch self {
        case .unsupported:
            "当前 AI 客户端不支持生成测评题包"
        case .batchFormatIncompatible(let details):
            "AI 批量题包格式不兼容：\(details)"
        }
    }
}
