import Foundation

enum SourceKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case gitRepository
    case markdownDirectory
    case remoteGitRepository
    case remoteGitMarkdown
    case manual

    var id: Self { self }

    var title: String {
        switch self {
        case .gitRepository: "Git 仓库"
        case .markdownDirectory: "本地 Markdown 目录"
        case .remoteGitRepository, .remoteGitMarkdown: "远程 Git 仓库"
        case .manual: "手动证据"
        }
    }

    var systemImage: String {
        switch self {
        case .gitRepository: "arrow.triangle.branch"
        case .markdownDirectory: "doc.text"
        case .remoteGitRepository, .remoteGitMarkdown: "icloud.and.arrow.down"
        case .manual: "square.and.pencil"
        }
    }
}
