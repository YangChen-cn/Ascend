import Foundation

struct ExportedSource: Codable, Sendable {
    let id: UUID
    let name: String
    let kind: SourceKind
    let path: String
    let isEnabled: Bool
    let analyzeWorkingTree: Bool
    let analyzeMarkdown: Bool?
    let analyzeCode: Bool?
    let authorFilter: String?
    let remoteURLString: String?
    let ignorePatternsText: String?
    let lastScannedAt: Date?
    let lastCursor: String?
    let lastUpstreamReference: String?

    init(
        id: UUID,
        name: String,
        kind: SourceKind,
        path: String,
        isEnabled: Bool,
        analyzeWorkingTree: Bool,
        analyzeMarkdown: Bool? = nil,
        analyzeCode: Bool? = nil,
        authorFilter: String? = nil,
        remoteURLString: String? = nil,
        ignorePatternsText: String? = nil,
        lastScannedAt: Date? = nil,
        lastCursor: String? = nil,
        lastUpstreamReference: String? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.path = path
        self.isEnabled = isEnabled
        self.analyzeWorkingTree = analyzeWorkingTree
        self.analyzeMarkdown = analyzeMarkdown
        self.analyzeCode = analyzeCode
        self.authorFilter = authorFilter
        self.remoteURLString = remoteURLString
        self.ignorePatternsText = ignorePatternsText
        self.lastScannedAt = lastScannedAt
        self.lastCursor = lastCursor
        self.lastUpstreamReference = lastUpstreamReference
    }
}
