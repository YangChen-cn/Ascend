import Foundation
import SwiftData

@Model
final class SourceConfiguration {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRawValue: String
    var path: String
    var isEnabled: Bool
    var analyzeWorkingTree: Bool
    var analyzeMarkdown: Bool = true
    var analyzeCode: Bool = true
    var authorFilter: String
    var ignorePatternsText: String
    var remoteURLString: String?
    var lastScannedAt: Date?
    var lastCursor: String?
    var lastUpstreamReference: String?
    var lastSyncError: String?

    init(
        id: UUID = UUID(),
        name: String,
        kind: SourceKind,
        path: String,
        isEnabled: Bool = true,
        analyzeWorkingTree: Bool = false,
        analyzeMarkdown: Bool = true,
        analyzeCode: Bool = true,
        authorFilter: String = "",
        remoteURLString: String? = nil,
        ignorePatternsText: String = ".git\nnode_modules\n.build\nbuild\ndist\nDerivedData"
    ) {
        self.id = id
        self.name = name
        self.kindRawValue = kind.rawValue
        self.path = path
        self.isEnabled = isEnabled
        self.analyzeWorkingTree = analyzeWorkingTree
        self.analyzeMarkdown = analyzeMarkdown
        self.analyzeCode = analyzeCode
        self.authorFilter = authorFilter
        self.remoteURLString = remoteURLString
        self.ignorePatternsText = ignorePatternsText
    }

    var kind: SourceKind {
        SourceKind(rawValue: kindRawValue) ?? .manual
    }

    var ignorePatterns: [String] {
        ignorePatternsText
            .split(whereSeparator: \.isNewline)
            .map(String.init)
    }
}
