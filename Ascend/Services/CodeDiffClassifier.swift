import CryptoKit
import Foundation

enum CodeDiffClassifier {
    private static let codeExtensions: Set<String> = [
        "c", "h", "cc", "cpp", "cxx", "hh", "hpp", "hxx",
        "swift", "py", "rs", "go", "java", "cs", "js", "jsx",
        "ts", "tsx", "sh", "bash", "zsh"
    ]

    private static let codeFileNames: Set<String> = [
        "makefile", "gnumakefile", "cmakelists.txt"
    ]

    static func isCodePath(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        let fileName = url.lastPathComponent.lowercased()
        return codeFileNames.contains(fileName) || codeExtensions.contains(url.pathExtension.lowercased())
    }

    static func assess(_ diff: String) -> CodeDiffAssessment {
        let changes = changedLines(in: diff)
        guard !changes.added.isEmpty || !changes.removed.isEmpty else {
            return CodeDiffAssessment(isSubstantive: false, reason: "仅重命名或无代码内容变化")
        }

        let normalizedAdded = changes.added.map(normalizeCodeLine).filter { !$0.isEmpty }
        let normalizedRemoved = changes.removed.map(normalizeCodeLine).filter { !$0.isEmpty }
        guard !normalizedAdded.isEmpty || !normalizedRemoved.isEmpty else {
            return CodeDiffAssessment(isSubstantive: false, reason: "仅空白或注释变化")
        }

        if normalizedAdded.sorted() == normalizedRemoved.sorted() {
            return CodeDiffAssessment(isSubstantive: false, reason: "仅格式化或代码移动")
        }
        return CodeDiffAssessment(isSubstantive: true, reason: "包含实质代码变化")
    }

    static func contentChangeHash(_ diff: String) -> String {
        let normalized = diff
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
        return SHA256.hash(data: Data(normalized.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func changedLines(in diff: String) -> (added: [String], removed: [String]) {
        var added: [String] = []
        var removed: [String] = []
        for line in diff.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.hasPrefix("+++") || line.hasPrefix("---") { continue }
            if line.hasPrefix("+") {
                added.append(String(line.dropFirst()))
            } else if line.hasPrefix("-") {
                removed.append(String(line.dropFirst()))
            }
        }
        return (added, removed)
    }

    private static func normalizeCodeLine(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") ||
            trimmed.hasPrefix("*") || (trimmed.hasPrefix("#") && !trimmed.hasPrefix("#include")) {
            return ""
        }
        return trimmed.filter { !$0.isWhitespace }
    }
}
