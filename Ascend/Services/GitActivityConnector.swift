import CryptoKit
import Foundation

actor GitActivityConnector: ActivitySourceConnector {
    private let runner: ProcessRunner
    private let gitURL = URL(fileURLWithPath: "/usr/bin/git")

    init(runner: ProcessRunner = ProcessRunner()) {
        self.runner = runner
    }

    func scan(source: SourceDescriptor) async throws -> [CollectedActivity] {
        let since = source.lastScannedAt?.timeIntervalSince1970 ?? Date.now.addingTimeInterval(-7 * 86_400).timeIntervalSince1970
        var logArguments = [
            "-C", source.path,
            "log", "--all", "--since=@\(Int(since))", "-n", "50",
            "--pretty=format:%H%x1f%ct%x1f%s%x1e"
        ]
        if let author = await resolveAuthor(for: source) {
            logArguments.append("--author=\(author)")
        }
        let log = try await runner.run(
            executableURL: gitURL,
            arguments: logArguments
        )
        var activities: [CollectedActivity] = []
        for record in log.split(separator: "\u{001e}") {
            let fields = record.split(separator: "\u{001f}", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 3, let timestamp = TimeInterval(fields[1]) else { continue }
            let hash = fields[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let subject = fields[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let diff = try await runner.run(
                executableURL: gitURL,
                arguments: ["-C", source.path, "show", "--format=", "--no-ext-diff", "--unified=3", hash]
            )
            let safeDiff = Self.redactAndLimit(diff)
            activities.append(
                CollectedActivity(
                    sourceID: source.id,
                    sourceKind: .gitRepository,
                    timestamp: Date(timeIntervalSince1970: timestamp),
                    fingerprint: hash,
                    title: subject.isEmpty ? "Git 提交" : subject,
                    sourceLocator: source.path + "#" + hash,
                    summary: "提交 \(hash.prefix(7)) · \(subject)",
                    excerpt: safeDiff
                )
            )
        }

        if source.analyzeWorkingTree {
            let diff = try await runner.run(
                executableURL: gitURL,
                arguments: ["-C", source.path, "diff", "--no-ext-diff", "--unified=3"]
            )
            if !diff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let safeDiff = Self.redactAndLimit(diff)
                let fingerprint = Self.hash(safeDiff)
                activities.append(
                    CollectedActivity(
                        sourceID: source.id,
                        sourceKind: .gitRepository,
                        timestamp: .now,
                        fingerprint: "working-tree-\(fingerprint)",
                        title: "未提交工作区改动",
                        sourceLocator: source.path,
                        summary: "已授权仓库的工作区改动",
                        excerpt: safeDiff
                    )
                )
            }
        }
        return activities
    }

    private static func redactAndLimit(_ text: String) -> String {
        let sensitiveMarkers = ["api_key", "apikey", "authorization:", "password", "secret", "private_key"]
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            let value = String(line)
            if sensitiveMarkers.contains(where: { value.lowercased().contains($0) }) {
                return "[敏感内容已隐藏]"
            }
            return value
        }
        return String(lines.joined(separator: "\n").prefix(AppConstants.maximumAuditExcerptLength))
    }

    private func resolveAuthor(for source: SourceDescriptor) async -> String? {
        if let custom = source.authorFilter?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom
        }
        if let email = try? await runner.run(
            executableURL: gitURL,
            arguments: ["-C", source.path, "config", "user.email"]
        ).trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            return email
        }
        if let name = try? await runner.run(
            executableURL: gitURL,
            arguments: ["-C", source.path, "config", "user.name"]
        ).trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        return nil
    }

    private static func hash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { byte in
            let value = String(byte, radix: 16)
            return value.count == 1 ? "0" + value : value
        }.joined()
    }
}
