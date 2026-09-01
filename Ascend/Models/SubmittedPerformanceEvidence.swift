import Foundation

/// 用户主动提交的实作来源。持久化时只保存定位、摘要和内容哈希；审计片段仅用于本次用户发起的 AI 核验。
struct SubmittedPerformanceEvidence: Sendable, Equatable {
    let title: String
    let sourceLocator: String
    let contentChangeHash: String
    let sourceKind: SourceKind
    let occurredAt: Date
    let auditExcerpt: String

    init(
        title: String,
        sourceLocator: String,
        contentChangeHash: String,
        sourceKind: SourceKind,
        occurredAt: Date,
        auditExcerpt: String = ""
    ) {
        self.title = title
        self.sourceLocator = sourceLocator
        self.contentChangeHash = contentChangeHash
        self.sourceKind = sourceKind
        self.occurredAt = occurredAt
        self.auditExcerpt = auditExcerpt
    }
}
