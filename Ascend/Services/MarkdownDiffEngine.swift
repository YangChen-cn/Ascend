import CryptoKit
import Foundation

struct MarkdownDiffResult: Sendable, Equatable {
    let hasChanges: Bool
    let diffExcerpt: String
    let normalizedDiffText: String
    let normalizedDiffHash: String
    let addedCount: Int
    let modifiedCount: Int
    let removedCount: Int
}

enum MarkdownDiffEngine {
    static func diff(oldContent: String, newContent: String) -> MarkdownDiffResult {
        let trimmedOld = oldContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNew = newContent.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. 无任何实质改动
        if trimmedOld == trimmedNew {
            let hash = hexDigest(normalizedText(trimmedNew))
            return MarkdownDiffResult(
                hasChanges: false,
                diffExcerpt: "",
                normalizedDiffText: "",
                normalizedDiffHash: hash,
                addedCount: 0,
                modifiedCount: 0,
                removedCount: 0
            )
        }

        // 2. 全新笔记（旧内容为空）
        if trimmedOld.isEmpty {
            let normalized = normalizedText(trimmedNew)
            let hash = hexDigest(normalized)
            let excerpt = String(trimmedNew.prefix(AppConstants.maximumAuditExcerptLength))
            return MarkdownDiffResult(
                hasChanges: true,
                diffExcerpt: excerpt,
                normalizedDiffText: normalized,
                normalizedDiffHash: hash,
                addedCount: 1,
                modifiedCount: 0,
                removedCount: 0
            )
        }

        // 3. 语义化章节切分与对比
        let oldSections = parseSections(oldContent)
        let newSections = parseSections(newContent)

        var excerptLines: [String] = []
        var normalizedTokens: [String] = []
        var addedCount = 0
        var modifiedCount = 0
        var removedCount = 0

        let oldMap = Dictionary(oldSections.map { ($0.heading, $0) }, uniquingKeysWith: { first, _ in first })

        for newSec in newSections {
            if let oldSec = oldMap[newSec.heading] {
                // 已有章节：对比正文
                let oldBodyNorm = normalizedText(oldSec.body)
                let newBodyNorm = normalizedText(newSec.body)

                if oldBodyNorm != newBodyNorm {
                    modifiedCount += 1
                    if !newSec.heading.isEmpty {
                        excerptLines.append("### [章节修订] \(newSec.heading)")
                    }
                    let lineDiffs = computeLineDiff(oldLines: oldSec.lines, newLines: newSec.lines)
                    excerptLines.append(contentsOf: lineDiffs.excerpt)
                    normalizedTokens.append(newBodyNorm)
                }
            } else {
                // 新增章节
                addedCount += 1
                if !newSec.heading.isEmpty {
                    excerptLines.append("### [新增章节] \(newSec.heading)")
                }
                for line in newSec.lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    excerptLines.append("+ \(line)")
                }
                let norm = normalizedText(newSec.body)
                normalizedTokens.append(norm)
            }
        }

        // 检查被删除的章节（仅计入统计，不作为负向证据扣分）
        let newHeadings = Set(newSections.map(\.heading))
        for oldSec in oldSections where !newHeadings.contains(oldSec.heading) {
            removedCount += 1
        }

        // 如果章节对比未能捕获细微改动（例如无标题的纯文本笔记），退化为行级 Diff
        if excerptLines.isEmpty && modifiedCount == 0 && addedCount == 0 {
            let lineDiffs = computeLineDiff(
                oldLines: oldContent.split(separator: "\n", omittingEmptySubsequences: false).map(String.init),
                newLines: newContent.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            )
            excerptLines = lineDiffs.excerpt
            if !lineDiffs.addedLines.isEmpty {
                addedCount += lineDiffs.addedLines.count
                normalizedTokens.append(normalizedText(lineDiffs.addedLines.joined(separator: "\n")))
            }
        }

        let combinedNormalized = normalizedTokens.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let hash = hexDigest(combinedNormalized.isEmpty ? normalizedText(newContent) : combinedNormalized)
        let fullExcerpt = String(excerptLines.joined(separator: "\n").prefix(AppConstants.maximumAuditExcerptLength))

        return MarkdownDiffResult(
            hasChanges: !excerptLines.isEmpty || addedCount > 0 || modifiedCount > 0,
            diffExcerpt: fullExcerpt.isEmpty ? String(newContent.prefix(AppConstants.maximumAuditExcerptLength)) : fullExcerpt,
            normalizedDiffText: combinedNormalized,
            normalizedDiffHash: hash,
            addedCount: addedCount,
            modifiedCount: modifiedCount,
            removedCount: removedCount
        )
    }

    // MARK: - 章节解析

    private struct MarkdownSection {
        let heading: String
        let lines: [String]
        var body: String {
            lines.joined(separator: "\n")
        }
    }

    private static func parseSections(_ content: String) -> [MarkdownSection] {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var sections: [MarkdownSection] = []
        var currentHeading = ""
        var currentLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                if !currentLines.isEmpty || !currentHeading.isEmpty {
                    sections.append(MarkdownSection(heading: currentHeading, lines: currentLines))
                    currentLines.removeAll()
                }
                currentHeading = trimmed
            } else {
                currentLines.append(line)
            }
        }

        if !currentLines.isEmpty || !currentHeading.isEmpty {
            sections.append(MarkdownSection(heading: currentHeading, lines: currentLines))
        }

        return sections
    }

    // MARK: - 行级细粒度 Diff

    private struct LineDiffResult {
        let excerpt: [String]
        let addedLines: [String]
    }

    private static func computeLineDiff(oldLines: [String], newLines: [String]) -> LineDiffResult {
        let oldSet = Set(oldLines.map { $0.trimmingCharacters(in: .whitespaces) })
        let newSet = Set(newLines.map { $0.trimmingCharacters(in: .whitespaces) })

        var excerpt: [String] = []
        var added: [String] = []

        for line in oldLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !newSet.contains(trimmed) {
                excerpt.append("- \(line)")
            }
        }

        for line in newLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !oldSet.contains(trimmed) {
                excerpt.append("+ \(line)")
                added.append(line)
            }
        }

        return LineDiffResult(excerpt: excerpt, addedLines: added)
    }

    // MARK: - 文本规范化与哈希

    static func normalizedText(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func hexDigest(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { byte in
            let value = String(byte, radix: 16)
            return value.count == 1 ? "0" + value : value
        }.joined()
    }
}
