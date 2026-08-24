import CryptoKit
import Foundation

actor RemoteGitRepositoryConnector: ActivitySourceConnector {
    private let runner: ProcessRunner
    private let gitURL = URL(fileURLWithPath: "/usr/bin/git")

    init(runner: ProcessRunner = ProcessRunner()) {
        self.runner = runner
    }

    func scan(source: SourceDescriptor) async throws -> ActivityScanResult {
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw ProcessRunner.ProcessError.failed(
                command: "git",
                terminationStatus: 128,
                stderr: "仓库路径不存在：\(source.path)"
            )
        }

        let upstream = try await upstreamReference(in: source.path)
        let remoteURL = await remoteURL(for: upstream, in: source.path)
        _ = try await runner.run(
            executableURL: gitURL,
            arguments: ["-C", source.path, "fetch", "--quiet"],
            timeout: 30
        )
        let remoteSHA = try await revisionSHA(upstream, in: source.path)

        if source.lastCursor == remoteSHA {
            return ActivityScanResult(
                activities: [],
                nextCursor: remoteSHA,
                upstreamReference: upstream,
                remoteURLString: remoteURL
            )
        }

        let cursorIsAncestor = await isUsableCursor(source.lastCursor, headSHA: remoteSHA, path: source.path)
        let logArguments: [String]
        if let cursor = source.lastCursor, !cursor.isEmpty, cursorIsAncestor {
            logArguments = [
                "-C", source.path, "log", "\(cursor)..\(upstream)",
                "--reverse", "--format=%H%x1f%at%x1f%s%x1e"
            ]
        } else {
            logArguments = [
                "-C", source.path, "log", "-n", "20", "--reverse",
                "--format=%H%x1f%at%x1f%s%x1e", upstream
            ]
        }

        let log = try await runner.run(
            executableURL: gitURL,
            arguments: logArguments,
            timeout: 60,
            maximumOutputBytes: 32 * 1_024 * 1_024
        )
        let activities = try await collectCommits(from: log, source: source)
        return ActivityScanResult(
            activities: activities,
            nextCursor: remoteSHA,
            upstreamReference: upstream,
            remoteURLString: remoteURL
        )
    }

    private func collectCommits(from log: String, source: SourceDescriptor) async throws -> [CollectedActivity] {
        var activities: [CollectedActivity] = []
        for record in log.split(separator: "\u{001e}") {
            let fields = record.split(separator: "\u{001f}", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 3, let timestamp = TimeInterval(fields[1]) else { continue }
            let hash = fields[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let subject = fields[2].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !hash.isEmpty else { continue }

            let changedFiles = try await changedFiles(commit: hash, source: source)
            if source.analyzeMarkdown {
                activities += try await markdownActivities(
                    commit: hash,
                    subject: subject,
                    timestamp: timestamp,
                    files: changedFiles.filter { $0.lowercased().hasSuffix(".md") },
                    source: source
                )
            }
            if source.analyzeCode {
                let codeFiles = changedFiles.filter(CodeDiffClassifier.isCodePath)
                if let activity = try await codeActivity(
                    commit: hash,
                    subject: subject,
                    timestamp: timestamp,
                    files: codeFiles,
                    source: source
                ) {
                    activities.append(activity)
                }
            }
        }
        return activities
    }

    private func changedFiles(commit: String, source: SourceDescriptor) async throws -> [String] {
        let output = try await runner.run(
            executableURL: gitURL,
            arguments: ["-C", source.path, "show", "--name-only", "--format=", "--find-renames", commit],
            timeout: 30
        )
        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !isIgnored($0, patterns: source.ignorePatterns) }
    }

    private func markdownActivities(
        commit: String,
        subject: String,
        timestamp: TimeInterval,
        files: [String],
        source: SourceDescriptor
    ) async throws -> [CollectedActivity] {
        var activities: [CollectedActivity] = []
        for filePath in files {
            let diff = try await commitDiff(commit: commit, files: [filePath], source: source, maximumBytes: 1 * 1_024 * 1_024)
            guard let contentChangeHash = MarkdownDiffEngine.contentChangeHash(fromGitDiff: diff) else { continue }
            let safeDiff = redactAndLimit(diff)
            guard !safeDiff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

            let fileName = URL(fileURLWithPath: filePath).lastPathComponent
            activities.append(
                CollectedActivity(
                    sourceID: source.id,
                    sourceKind: .remoteGitRepository,
                    timestamp: Date(timeIntervalSince1970: timestamp),
                    fingerprint: "remote-markdown-event-\(source.id.uuidString)-\(commit)-\(digest(filePath).prefix(12))-\(contentChangeHash.prefix(12))",
                    contentChangeHash: contentChangeHash,
                    title: subject.isEmpty ? "Markdown 提交 · \(fileName)" : subject,
                    sourceLocator: "\(source.path)#\(commit):\(filePath)",
                    summary: "[Markdown 学习笔记] \(fileName) · commit \(commit.prefix(7))",
                    excerpt: safeDiff
                )
            )
        }
        return activities
    }

    private func codeActivity(
        commit: String,
        subject: String,
        timestamp: TimeInterval,
        files: [String],
        source: SourceDescriptor
    ) async throws -> CollectedActivity? {
        guard !files.isEmpty else { return nil }
        let diff = try await commitDiff(commit: commit, files: files, source: source, maximumBytes: 2 * 1_024 * 1_024)
        guard !diff.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let assessment = CodeDiffClassifier.assess(diff)
        let contentChangeHash = CodeDiffClassifier.contentChangeHash(diff)
        let safeDiff = redactAndLimit(diff)
        let visibleFiles = files.prefix(12).joined(separator: ", ")
        let remaining = files.count > 12 ? " 等 \(files.count) 个文件" : ""
        let valueMarker = assessment.isSubstantive ? "代码实践" : "低信息代码变更"
        let excerpt = """
        远程代码提交：\(commit)
        变更文件：\(visibleFiles)\(remaining)
        预检判断：\(assessment.reason)

        \(safeDiff)
        """

        return CollectedActivity(
            sourceID: source.id,
            sourceKind: .remoteGitRepository,
            timestamp: Date(timeIntervalSince1970: timestamp),
            fingerprint: "remote-code-event-\(source.id.uuidString)-\(commit)-\(contentChangeHash.prefix(12))",
            contentChangeHash: contentChangeHash,
            title: subject.isEmpty ? "远程代码提交" : subject,
            sourceLocator: "\(source.path)#\(commit):code",
            summary: "[\(valueMarker)] \(files.count) 个代码文件 · commit \(commit.prefix(7))",
            excerpt: excerpt,
            isSubstantiveCodeChange: assessment.isSubstantive
        )
    }

    private func commitDiff(
        commit: String,
        files: [String],
        source: SourceDescriptor,
        maximumBytes: Int
    ) async throws -> String {
        try await runner.run(
            executableURL: gitURL,
            arguments: [
                "-C", source.path, "show", "--format=", "--find-renames",
                "--no-ext-diff", "--unified=3", commit, "--"
            ] + files,
            timeout: 60,
            maximumOutputBytes: maximumBytes,
            allowTruncatedOutput: true
        )
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

    private func remoteURL(for upstream: String, in path: String) async -> String? {
        guard let remoteName = upstream.split(separator: "/").first else { return nil }
        return try? await runner.run(
            executableURL: gitURL,
            arguments: ["-C", path, "remote", "get-url", String(remoteName)],
            timeout: 30
        ).trimmingCharacters(in: .whitespacesAndNewlines)
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
        if relativePath.split(separator: "/").contains(where: { $0.hasPrefix(".") }) { return true }
        return patterns.contains { pattern in
            !pattern.isEmpty && relativePath.localizedStandardContains(pattern)
        }
    }

    private func redactAndLimit(_ text: String) -> String {
        let sensitiveMarkers = ["api_key", "apikey", "authorization:", "password", "secret", "private_key"]
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            let value = String(line)
            return sensitiveMarkers.contains(where: { value.lowercased().contains($0) })
                ? "[敏感内容已隐藏]"
                : value
        }
        return String(lines.joined(separator: "\n").prefix(AppConstants.maximumAuditExcerptLength))
    }

    private func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
