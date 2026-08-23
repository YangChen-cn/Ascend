import Foundation

struct ExportedSource: Codable, Sendable {
    let id: UUID
    let name: String
    let kind: SourceKind
    let path: String
    let isEnabled: Bool
    let analyzeWorkingTree: Bool
}
