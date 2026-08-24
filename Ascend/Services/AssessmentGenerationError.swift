import Foundation

enum AssessmentGenerationError: LocalizedError {
    case unsupported

    var errorDescription: String? {
        "当前 AI 客户端不支持生成测评题包"
    }
}
