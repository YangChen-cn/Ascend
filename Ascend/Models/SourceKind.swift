import Foundation

enum SourceKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case gitRepository
    case markdownDirectory
    case manual

    var id: Self { self }

    var title: String {
        switch self {
        case .gitRepository: "Git 仓库"
        case .markdownDirectory: "Markdown 目录"
        case .manual: "手动证据"
        }
    }

    var systemImage: String {
        switch self {
        case .gitRepository: "arrow.triangle.branch"
        case .markdownDirectory: "doc.text"
        case .manual: "square.and.pencil"
        }
    }
}
