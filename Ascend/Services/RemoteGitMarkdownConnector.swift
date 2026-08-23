import CryptoKit
import Foundation

actor RemoteGitMarkdownConnector: ActivitySourceConnector {
    private let runner: ProcessRunner
    private let gitURL = URL(fileURLWithPath: "/usr/bin/git")

    init(runner: ProcessRunner = ProcessRunner()) {
        self.runner = runner
    }

    func scan(source: SourceDescriptor) async throws -> ActivityScanResult {
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw ProcessRunner.ProcessError.failed(command: "git", terminationStatus: 128, stderr: "仓库路径不存在：\(source.path)")
        }

        let upstream = try await upstreamReference(in: source.path)

        // fetch 失败必须向上抛出，由数据源状态记录明确的同步错误。
        _ = try await runner.run(
            executableURL: gitURL,
            arguments: ["-C", source.path, "fetch", "--quiet"],
            timeout: 30
        )

        let remoteSHA = try await revisionSHA(upstream, in: source.path)

        if let lastCursor = source.lastCursor, lastCursor == remoteSHA {
            return ActivityScanResult(activities: [], nextCursor: remoteSHA)
        }

        let isAncestor = await isUsableCursor(source.lastCursor, headSHA: remoteSHA, path: source.path)
        let logArguments: [String]
        if let lastCursor = source.lastCursor, !lastCursor.isEmpty, isAncestor {
            logArguments = ["-C", source.path, "log", "\(lastCursor)..\(upstream)", "--reverse", "--format=%H%x1f%at%x1f%s%x1e"]
        } else {
            // 首次接入或游标重置，按时间正序处理最近 20 个提交
            logArguments = ["-C", source.path, "log", "-n", "20", "--reverse", "--format=%H%x1f%at%x1f%s%x1e", upstream]
        }

        let log = try await runner.run(
            executableURL: gitURL,
            arguments: logArguments,
            timeout: 60,
            maximumOutputBytes: 32 * 1_024 * 1_024
        )

        let activities = try await collectMarkdownCommits(from: log, source: source)
        return ActivityScanResult(activities: activities, nextCursor: remoteSHA)
    }

    // MARK: - 提交解析

    private func collectMarkdownCommits(from log: String, source: SourceDescriptor) async throws -> [CollectedActivity] {
        var activities: [CollectedActivity] = []

        for record in log.split(separator: "\u{001e}") {
            let fields = record.split(separator: "\u{001f}", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 3, let timestamp = TimeInterval(fields[1]) else { continue }
            let hash = fields[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let subject = fields[2].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !hash.isEmpty else { continue }

            // 获取该 commit 变动的文件列表
            let changedFilesOutput = try await runner.run(
                executableURL: gitURL,
                arguments: ["-C", source.path, "show", "--name-only", "--format=", hash],
                timeout: 30
            )

            let changedFiles = changedFilesOutput
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.lowercased().hasSuffix(".md") && !isIgnored($0, patterns: source.ignorePatterns) }

            // 若本提交未修改任何 Markdown 笔记，则跳过
            guard !changedFiles.isEmpty else { continue }

            for filePath in changedFiles {
                let diff = try await runner.run(
                    executableURL: gitURL,
                    arguments: ["-C", source.path, "show", "--format=", "--no-ext-diff", "--unified=3", hash, "--", filePath],
                    timeout: 45,
                    maximumOutputBytes: 1 * 1_024 * 1_024,
                    allowTruncatedOutput: true
                )

                // 纯删除或仅重命名不构成新的学习证据。
                guard let contentChangeHash = MarkdownDiffEngine.contentChangeHash(fromGitDiff: diff) else { continue }
                let safeDiff = redactAndLimit(diff)
                guard !safeDiff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

                let fileName = URL(fileURLWithPath: filePath).lastPathComponent
                let title = subject.isEmpty ? "Markdown 提交 · \(fileName)" : subject

                activities.append(
                    CollectedActivity(
                        sourceID: source.id,
                        sourceKind: .remoteGitMarkdown,
                        timestamp: Date(timeIntervalSince1970: timestamp),
                        fingerprint: "remote-markdown-event-\(hash)-\(MarkdownDiffEngine.hexDigest(filePath).prefix(12))",
                        contentChangeHash: contentChangeHash,
                        title: title,
                        sourceLocator: "\(source.path)#\(hash):\(filePath)",
                        summary: "远程 Git 笔记 · \(fileName) (\(hash.prefix(7)))",
                        excerpt: safeDiff
                    )
                )
            }
        }

        return activities
    }

    private func upstreamReference(in path: String) async throws -> String {
        let value = try await runner.run(
            executableURL: gitURL,
            arguments: ["-C", path, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"],
            timeout: 30
        )
        let upstream = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !upstream.isEmpty else {
            throw ProcessRunner.ProcessError.failed(
                command: "git",
                terminationStatus: 128,
                stderr: "当前分支没有配置 upstream tracking branch"
            )
        }
        return upstream
    }

    private func revisionSHA(_ revision: String, in path: String) async throws -> String {
        let value = try await runner.run(
            executableURL: gitURL,
            arguments: ["-C", path, "rev-parse", "--verify", revision],
            timeout: 30
        )
        let sha = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sha.isEmpty else {
            throw ProcessRunner.ProcessError.failed(
                command: "git",
                terminationStatus: 128,
                stderr: "无法解析远端 tracking branch：\(revision)"
            )
        }
        return sha
    }

    private func isUsableCursor(_ cursor: String?, headSHA: String, path: String) async -> Bool {
        guard let cursor, !cursor.isEmpty, cursor != headSHA else { return cursor == headSHA }
        return (try? await runner.run(
            executableURL: gitURL,
            arguments: ["-C", path, "merge-base", "--is-ancestor", cursor, headSHA],
            timeout: 30
        )) != nil
    }

    private func isIgnored(_ relativePath: String, patterns: [String]) -> Bool {
        let components = relativePath.split(separator: "/")
        for comp in components {
            if comp.hasPrefix(".") { return true }
        }
        return patterns.contains { pattern in
            !pattern.isEmpty && relativePath.localizedStandardContains(pattern)
        }
    }

    private func redactAndLimit(_ text: String) -> String {
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
}
