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

        // 尝试非阻塞拉取远端变更（若配置了 remote）
        _ = try? await runner.run(
            executableURL: gitURL,
            arguments: ["-C", source.path, "fetch", "--quiet"],
            timeout: 30
        )

        guard let headSHA = try await currentHead(in: source.path) else {
            return ActivityScanResult(activities: [], nextCursor: nil)
        }

        // 若 HEAD 未变动，直接返回无新活动
        if let lastCursor = source.lastCursor, lastCursor == headSHA {
            return ActivityScanResult(activities: [], nextCursor: headSHA)
        }

        let isAncestor = await isUsableCursor(source.lastCursor, headSHA: headSHA, path: source.path)
        let logArguments: [String]
        if let lastCursor = source.lastCursor, !lastCursor.isEmpty, isAncestor {
            logArguments = ["-C", source.path, "log", "\(lastCursor)..HEAD", "--reverse", "--format=%H%x1f%at%x1f%s%x1e"]
        } else {
            // 首次接入或游标重置，按时间正序处理最近 20 个提交
            logArguments = ["-C", source.path, "log", "-n", "20", "--reverse", "--format=%H%x1f%at%x1f%s%x1e", "HEAD"]
        }

        let log = try await runner.run(
            executableURL: gitURL,
            arguments: logArguments,
            timeout: 60,
            maximumOutputBytes: 32 * 1_024 * 1_024
        )

        let activities = try await collectMarkdownCommits(from: log, source: source)
        return ActivityScanResult(activities: activities, nextCursor: headSHA)
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

                let safeDiff = redactAndLimit(diff)
                guard !safeDiff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

                // 提取差量中新增/修改的文本行计算 normalizedDiffHash
                let addedLines = safeDiff.split(separator: "\n")
                    .filter { $0.hasPrefix("+") && !$0.hasPrefix("+++") }
                    .map { String($0.dropFirst()) }
                    .joined(separator: "\n")

                let normalizedDiffHash = MarkdownDiffEngine.hexDigest(
                    MarkdownDiffEngine.normalizedText(addedLines.isEmpty ? safeDiff : addedLines)
                )

                let fileName = URL(fileURLWithPath: filePath).lastPathComponent
                let title = subject.isEmpty ? "Markdown 提交 · \(fileName)" : subject

                activities.append(
                    CollectedActivity(
                        sourceID: source.id,
                        sourceKind: .remoteGitMarkdown,
                        timestamp: Date(timeIntervalSince1970: timestamp),
                        fingerprint: "\(hash)-\(normalizedDiffHash.prefix(12))",
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

    private func currentHead(in path: String) async throws -> String? {
        do {
            let value = try await runner.run(
                executableURL: gitURL,
                arguments: ["-C", path, "rev-parse", "--verify", "HEAD"],
                timeout: 30
            )
            let head = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return head.isEmpty ? nil : head
        } catch ProcessRunner.ProcessError.failed(_, let terminationStatus, _) where terminationStatus == 128 {
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
