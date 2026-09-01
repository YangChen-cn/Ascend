import Foundation

/// 用户主动提交的实作来源。仅保存定位、摘要和内容哈希，不保存原始文件或源码。
struct SubmittedPerformanceEvidence: Sendable, Equatable {
    let title: String
    let sourceLocator: String
    let contentChangeHash: String
    let sourceKind: SourceKind
    let occurredAt: Date
}
