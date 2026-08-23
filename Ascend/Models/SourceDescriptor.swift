import Foundation

struct SourceDescriptor: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let kind: SourceKind
    let path: String
    let analyzeWorkingTree: Bool
    let authorFilter: String?
    let ignorePatterns: [String]
    let lastScannedAt: Date?
    let lastCursor: String?
}
