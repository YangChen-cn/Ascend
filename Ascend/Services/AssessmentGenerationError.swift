import Foundation

enum AssessmentGenerationError: LocalizedError {
    case unsupported
    case batchFormatIncompatible(String)
    case transportInterrupted(String)

    var adaptiveFallbackDetails: String? {
        switch self {
        case .batchFormatIncompatible(let details), .transportInterrupted(let details):
            details
        case .unsupported:
            "当前 AI 客户端不支持批量题包"
        }
    }

    var errorDescription: String? {
        switch self {
        case .unsupported:
            "当前 AI 客户端不支持生成测评题包"
        case .batchFormatIncompatible(let details):
            "AI 批量题包格式不兼容：\(details)"
        case .transportInterrupted(let details):
            "AI 响应传输中断：\(details)"
        }
    }
}
