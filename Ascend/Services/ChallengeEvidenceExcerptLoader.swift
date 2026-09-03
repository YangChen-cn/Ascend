import Foundation

/// 在用户明确提交挑战证据时，从本地已授权的 Git checkout 重取该 commit 的受限 Diff。
/// 不持久化完整 Diff；仅返回本次 AI 核验所需、按目标相关性排序的片段。
actor ChallengeEvidenceExcerptLoader {
    private let runner: ProcessRunner
    private let gitURL = URL(fileURLWithPath: "/usr/bin/git")

    init(runner: ProcessRunner = ProcessRunner()) {
        self.runner = runner
    }

    func load(
        source: SubmittedPerformanceEvidence,
        focusTexts: [String]
    ) async throws -> String? {
        guard let location = Self.gitCommitLocation(for: source) else { return nil }
        let selectedPaths = source.selectedFilePaths.filter(Self.isSafeRepositoryRelativePath)
        guard selectedPaths.count == source.selectedFilePaths.count else {
            throw ChallengeEvidenceExcerptError.invalidSelectedPath
        }
        var arguments = [
            "-C", location.repositoryPath,
            "show", "--format=", "--find-renames", "--no-ext-diff", "--unified=3", location.commit
        ]
        if !selectedPaths.isEmpty {
            arguments.append("--")
            arguments.append(contentsOf: selectedPaths)
        }
        let diff = try await runner.run(
            executableURL: gitURL,
            arguments: arguments,
            timeout: 60,
            maximumOutputBytes: 2 * 1_024 * 1_024,
            allowTruncatedOutput: true
        )
        return Self.makeExcerpt(
            from: diff,
            focusTexts: focusTexts,
            selectedFileCount: selectedPaths.isEmpty ? nil : selectedPaths.count
        )
    }

    /// 返回聚合提交内可供人工挑选的代码文件。单文件 Markdown Activity 不进入此流程。
    func changedCodeFiles(source: SubmittedPerformanceEvidence) async throws -> [String] {
        guard let location = Self.gitCommitLocation(for: source) else { return [] }
        let output = try await runner.run(
            executableURL: gitURL,
            arguments: [
                "-C", location.repositoryPath,
                "show", "--name-only", "--pretty=format:", "--find-renames", location.commit
            ],
            timeout: 30,
            maximumOutputBytes: 512 * 1_024,
            allowTruncatedOutput: false
        )
        var seen = Set<String>()
        return output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { Self.isSafeRepositoryRelativePath($0) && CodeDiffClassifier.isCodePath($0) }
            .filter { seen.insert($0).inserted }
    }

    static func makeExcerpt(
        from diff: String,
        focusTexts: [String],
        selectedFileCount: Int? = nil
    ) -> String {
        let redacted = redact(diff)
        let sections = splitDiffSections(redacted)
        guard !sections.isEmpty else {
            return String(redacted.prefix(AppConstants.maximumChallengeEvidenceExcerptLength))
        }
        let terms = expandedFocusTerms(focusTexts)
        let ordered = selectedFileCount == nil
            ? sections.enumerated().sorted { lhs, rhs in
                let left = relevance(lhs.element, terms: terms)
                let right = relevance(rhs.element, terms: terms)
                return left == right ? lhs.offset < rhs.offset : left > right
            }.map(\.element)
            : sections

        let introduction = if let selectedFileCount {
            "受限 Git 审计片段：用户明确选择 \(selectedFileCount) 个文件；仅核验所选文件。\n"
        } else {
            "受限 Git 审计片段：共 \(sections.count) 个变更文件；优先展示与挑战目标相关的文件。\n"
        }
        var result = introduction
        for (index, section) in ordered.enumerated() {
            let remaining = AppConstants.maximumChallengeEvidenceExcerptLength - result.count
            guard remaining > 120 else { break }
            if selectedFileCount == 1 {
                result += "\n" + String(section.prefix(remaining)) + "\n"
                continue
            }
            let score = relevance(section, terms: terms)
            let remainingSections = max(1, ordered.count - index)
            let fairSelectedLimit = max(420, remaining / remainingSections)
            let desiredLimit = selectedFileCount == nil
                ? (score >= 3 ? 7_000 : (score > 0 ? 2_800 : 420))
                : fairSelectedLimit
            result += "\n" + focusedSectionExcerpt(
                section,
                terms: terms,
                maximumCharacters: min(desiredLimit, remaining)
            ) + "\n"
        }
        return result
    }

    static func gitCommitLocation(for source: SubmittedPerformanceEvidence) -> (repositoryPath: String, commit: String)? {
        guard source.sourceKind == .gitRepository || source.sourceKind == .remoteGitRepository,
              let marker = source.sourceLocator.lastIndex(of: "#") else { return nil }
        let repositoryPath = String(source.sourceLocator[..<marker])
        let suffix = source.sourceLocator[source.sourceLocator.index(after: marker)...]
        let components = suffix.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        if source.sourceKind == .remoteGitRepository,
           (components.count != 2 || components[1] != "code") {
            return nil
        }
        if source.sourceKind == .gitRepository, components.count > 1, components[1] != "code" {
            return nil
        }
        let commit = String(components[0])
        let isHexCommit = (7...64).contains(commit.count) && commit.allSatisfy(\.isHexDigit)
        guard !repositoryPath.isEmpty, isHexCommit else { return nil }
        return (repositoryPath, commit)
    }

    private static func isSafeRepositoryRelativePath(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\0") else { return false }
        return !path.split(separator: "/", omittingEmptySubsequences: false).contains("..")
    }

    private static func splitDiffSections(_ diff: String) -> [String] {
        var sections: [String] = []
        var current = ""
        for line in diff.split(separator: "\n", omittingEmptySubsequences: false) {
            let value = String(line)
            if value.hasPrefix("diff --git "), !current.isEmpty {
                sections.append(current)
                current = ""
            }
            current += value + "\n"
        }
        if !current.isEmpty { sections.append(current) }
        return sections
    }

    private static func relevance(_ section: String, terms: [String]) -> Int {
        let lowercased = section.lowercased()
        return terms.reduce(0) { $0 + (lowercased.contains($1) ? 1 : 0) }
    }

    private static func focusedSectionExcerpt(
        _ section: String,
        terms: [String],
        maximumCharacters: Int
    ) -> String {
        let lines = section.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard !lines.isEmpty else { return "" }
        var selected = Set(0..<min(6, lines.count))
        // 每个关注词只保留首次与末次命中，避免某个高频词（如 pipe）吃光预算，
        // 同时保证位于文件尾部的 waitpid/EINTR 等独立要求不会被前半段挤掉。
        let matchingIndices = Array(Set(terms.flatMap { term -> [Int] in
            let matches = lines.indices.filter { lines[$0].lowercased().contains(term) }
            guard let first = matches.first, let last = matches.last else { return [] }
            return first == last ? [first] : [first, last]
        })).sorted()
        for index in matchingIndices {
            let lower = max(0, index - 5)
            let upper = min(lines.count - 1, index + 7)
            selected.formUnion(lower...upper)
        }
        if matchingIndices.isEmpty {
            selected.formUnion(0..<min(16, lines.count))
        }

        var output = ""
        var previousIndex: Int?
        for index in selected.sorted() {
            if let previousIndex, index > previousIndex + 1 {
                output += "…（省略无关行）…\n"
            }
            let next = lines[index] + "\n"
            guard output.count + next.count <= maximumCharacters else {
                output += "…（本文件其余无关上下文已省略）…\n"
                break
            }
            output += next
            previousIndex = index
        }
        return output
    }

    private static func expandedFocusTerms(_ values: [String]) -> [String] {
        let text = values.joined(separator: " ").lowercased()
        var terms = text
            .split { !$0.isLetter && !$0.isNumber && $0 != "/" && $0 != "_" }
            .map(String.init)
            .filter { $0.count >= 3 }
        let mappings: [(String, [String])] = [
            ("管道", ["pipe", "read(", "write(", "close("]),
            ("进程", ["fork", "waitpid", "setsid"]),
            ("信号", ["sigaction", "signal", "sigterm", "sigint"]),
            ("eintr", ["eintr", "waitpid"]),
            ("守护", ["setsid", "fork", "daemon"]),
            ("/proc", ["/proc", "meminfo", "stat"])
        ]
        for (hint, additions) in mappings where text.contains(hint) {
            terms.append(contentsOf: additions)
        }
        return Array(Set(terms))
    }

    private static func redact(_ text: String) -> String {
        let sensitiveMarkers = ["api_key", "apikey", "authorization:", "password", "secret", "private_key"]
        return text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                let value = String(line)
                return sensitiveMarkers.contains(where: { value.lowercased().contains($0) })
                    ? "[敏感内容已隐藏]"
                    : value
            }
            .joined(separator: "\n")
    }
}

enum ChallengeEvidenceExcerptError: LocalizedError {
    case invalidSelectedPath

    var errorDescription: String? {
        switch self {
        case .invalidSelectedPath:
            "所选 Git 文件路径无效，请重新选择。"
        }
    }
}
