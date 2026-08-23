import Foundation

struct ExportedSource: Codable, Sendable {
    let id: UUID
    let name: String
    let kind: SourceKind
    let path: String
    let isEnabled: Bool
    let analyzeWorkingTree: Bool
    let authorFilter: String?

    init(
        id: UUID,
        name: String,
        kind: SourceKind,
        path: String,
        isEnabled: Bool,
        analyzeWorkingTree: Bool,
        authorFilter: String? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.path = path
        self.isEnabled = isEnabled
        self.analyzeWorkingTree = analyzeWorkingTree
        self.authorFilter = authorFilter
    }
}
