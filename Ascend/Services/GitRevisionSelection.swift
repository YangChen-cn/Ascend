import Foundation

enum GitRevisionSelection: Equatable, Sendable {
    case initial(headSHA: String, since: Date, maximumCommitCount: Int)
    case incremental(range: String)

    static func make(
        headSHA: String,
        lastCursor: String?,
        lastScannedAt: Date?,
        cursorIsAncestor: Bool,
        now: Date = .now
    ) -> Self {
        if let lastCursor, !lastCursor.isEmpty, cursorIsAncestor {
            return .incremental(range: "\(lastCursor)..\(headSHA)")
        }
        return .initial(
            headSHA: headSHA,
            since: lastScannedAt ?? now.addingTimeInterval(-7 * 86_400),
            maximumCommitCount: 200
        )
    }

    var logArguments: [String] {
        switch self {
        case .initial(let headSHA, let since, let maximumCommitCount):
            [
                "log", headSHA,
                "--since=@\(Int(since.timeIntervalSince1970))",
                "--max-count=\(maximumCommitCount)",
                "--reverse",
                "--pretty=format:%H%x1f%ct%x1f%s%x1e"
            ]
        case .incremental(let range):
            [
                "log", range,
                "--reverse",
                "--pretty=format:%H%x1f%ct%x1f%s%x1e"
            ]
        }
    }
}
