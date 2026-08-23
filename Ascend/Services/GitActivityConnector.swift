import CryptoKit
import Foundation

actor GitActivityConnector: ActivitySourceConnector {
    private let runner: ProcessRunner
    private let gitURL = URL(fileURLWithPath: "/usr/bin/git")

    init(runner: ProcessRunner = ProcessRunner()) {
        self.runner = runner
    }

    func scan(source: SourceDescriptor) async throws -> ActivityScanResult {
        let headSHA = try await currentHead(in: source.path)
        var activities: [CollectedActivity] = []

        if let headSHA {
            let cursorIsAncestor = await isUsableCursor(source.lastCursor, headSHA: headSHA, path: source.path)
            let selection = GitRevisionSelection.make(
                headSHA: headSHA,
                lastCursor: source.lastCursor,
                lastScannedAt: source.lastScannedAt,
                cursorIsAncestor: cursorIsAncestor
            )
            var logArguments = ["-C", source.path] + selection.logArguments
            if let author = await resolveAuthor(for: source) {
                logArguments.append("--author=\(author)")
            }
            let log = try await runner.run(
                executableURL: gitURL,
                arguments: logArguments,
                timeout: 120,
                maximumOutputBytes: 64 * 1_024 * 1_024
            )
            activities += try await collectCommits(from: log, source: source)
        }

        if source.analyzeWorkingTree {
            activities += try await collectWorkingTree(source: source)
        }
        return ActivityScanResult(activities: activities, nextCursor: headSHA)
    }

    private func collectCommits(from log: String, source: SourceDescriptor) async throws -> [CollectedActivity] {
        var activities: [CollectedActivity] = []
        for record in log.split(separator: "\u{001e}") {
            let fields = record.split(separator: "\u{001f}", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 3, let timestamp = TimeInterval(fields[1]) else { continue }
            let hash = fields[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let subject = fields[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let diff = try await runner.run(
                executableURL: gitURL,
                arguments: ["-C", source.path, "show", "--format=", "--no-ext-diff", "--unified=3", hash],
                timeout: 120,
                maximumOutputBytes: 1 * 1_024 * 1_024,
                allowTruncatedOutput: true
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

        return activities
    }

    private func collectWorkingTree(source: SourceDescriptor) async throws -> [CollectedActivity] {
        let diff = try await runner.run(
            executableURL: gitURL,
            arguments: ["-C", source.path, "diff", "--no-ext-diff", "--unified=3"],
            timeout: 120,
            maximumOutputBytes: 1 * 1_024 * 1_024,
            allowTruncatedOutput: true
        )
        guard !diff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let safeDiff = Self.redactAndLimit(diff)
        let fingerprint = Self.hash(safeDiff)
        return [
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
        ]
    }

    private func currentHead(in path: String) async throws -> String? {
        do {
            let value = try await runner.run(
                executableURL: gitURL,
                arguments: ["-C", path, "rev-parse", "--verify", "HEAD"],
                timeout: 30
            )
            let head = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return head.isEmpty ? nil : head
        } catch ProcessRunner.ProcessError.failed(_, let status, _) where status == 128 {
            return nil
        }
    }

    private func isUsableCursor(_ cursor: String?, headSHA: String, path: String) async -> Bool {
        guard let cursor, !cursor.isEmpty, cursor != headSHA else { return cursor == headSHA }
        return (try? await runner.run(
            executableURL: gitURL,
            arguments: ["-C", path, "merge-base", "--is-ancestor", cursor, headSHA],
            timeout: 30
        )) != nil
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
