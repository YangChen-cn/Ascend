import Foundation

struct SourceDescriptor: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let kind: SourceKind
    let path: String
    let analyzeWorkingTree: Bool
    let analyzeMarkdown: Bool
    let analyzeCode: Bool
    let authorFilter: String?
    let ignorePatterns: [String]
    let lastScannedAt: Date?
    let lastCursor: String?

    init(
        id: UUID = UUID(),
        name: String,
        kind: SourceKind,
        path: String,
        analyzeWorkingTree: Bool = false,
        analyzeMarkdown: Bool = true,
        analyzeCode: Bool = true,
        authorFilter: String? = nil,
        ignorePatterns: [String] = [],
        lastScannedAt: Date? = nil,
        lastCursor: String? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.path = path
        self.analyzeWorkingTree = analyzeWorkingTree
        self.analyzeMarkdown = analyzeMarkdown
        self.analyzeCode = analyzeCode
        self.authorFilter = authorFilter
        self.ignorePatterns = ignorePatterns
        self.lastScannedAt = lastScannedAt
        self.lastCursor = lastCursor
    }
}
