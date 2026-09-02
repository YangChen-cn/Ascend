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
        guard let location = Self.gitCodeLocation(from: source.sourceLocator) else { return nil }
        let diff = try await runner.run(
            executableURL: gitURL,
            arguments: [
                "-C", location.repositoryPath,
                "show", "--format=", "--find-renames", "--no-ext-diff", "--unified=3", location.commit
            ],
            timeout: 60,
            maximumOutputBytes: 2 * 1_024 * 1_024,
            allowTruncatedOutput: true
        )
        return Self.makeExcerpt(from: diff, focusTexts: focusTexts)
    }

    static func makeExcerpt(from diff: String, focusTexts: [String]) -> String {
        let redacted = redact(diff)
        let sections = splitDiffSections(redacted)
        guard !sections.isEmpty else {
            return String(redacted.prefix(AppConstants.maximumChallengeEvidenceExcerptLength))
        }
        let terms = expandedFocusTerms(focusTexts)
        let ordered = sections.enumerated().sorted { lhs, rhs in
            let left = relevance(lhs.element, terms: terms)
            let right = relevance(rhs.element, terms: terms)
            return left == right ? lhs.offset < rhs.offset : left > right
        }.map(\.element)

        var result = "受限 Git 审计片段：共 \(sections.count) 个变更文件；优先展示与挑战目标相关的文件。\n"
        for section in ordered {
            let remaining = AppConstants.maximumChallengeEvidenceExcerptLength - result.count
            guard remaining > 120 else { break }
            // 每个文件至少留下定位和少量上下文，避免 13 文件提交只看见第一个 Makefile。
            let perSectionLimit = min(1_400, remaining)
            result += "\n" + String(section.prefix(perSectionLimit)) + "\n"
        }
        return result
    }

    private static func gitCodeLocation(from locator: String) -> (repositoryPath: String, commit: String)? {
        guard let marker = locator.lastIndex(of: "#") else { return nil }
        let repositoryPath = String(locator[..<marker])
        let suffix = locator[locator.index(after: marker)...]
        guard let separator = suffix.firstIndex(of: ":"),
              suffix[suffix.index(after: separator)...] == "code" else { return nil }
        let commit = String(suffix[..<separator])
        guard !repositoryPath.isEmpty, !commit.isEmpty else { return nil }
        return (repositoryPath, commit)
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
