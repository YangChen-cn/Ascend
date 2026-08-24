import Foundation

struct CollectedActivity: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let sourceID: UUID
    let sourceKind: SourceKind
    let timestamp: Date
    let fingerprint: String
    let contentChangeHash: String?
    let title: String
    let sourceLocator: String
    let summary: String
    let excerpt: String
    /// 本地预检结构化标志：代码 diff 无实质行为变化（格式化/移动/注释等）时为 false，
    /// 分析层据此丢弃高价值 evidence，不依赖 summary 文案前缀
    var isSubstantiveCodeChange: Bool?

    init(
        id: UUID = UUID(),
        sourceID: UUID,
        sourceKind: SourceKind,
        timestamp: Date,
        fingerprint: String,
        contentChangeHash: String? = nil,
        title: String,
        sourceLocator: String,
        summary: String,
        excerpt: String,
        isSubstantiveCodeChange: Bool? = nil
    ) {
        self.id = id
        self.sourceID = sourceID
        self.sourceKind = sourceKind
        self.timestamp = timestamp
        self.fingerprint = fingerprint
        self.contentChangeHash = contentChangeHash
        self.title = title
        self.sourceLocator = sourceLocator
        self.summary = summary
        self.excerpt = excerpt
        self.isSubstantiveCodeChange = isSubstantiveCodeChange
    }
}
