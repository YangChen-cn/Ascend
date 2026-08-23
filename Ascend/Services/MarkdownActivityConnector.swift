import CryptoKit
import Foundation

actor MarkdownActivityConnector: ActivitySourceConnector {
    private let snapshotStore: MarkdownSnapshotStore

    init(snapshotStore: MarkdownSnapshotStore = MarkdownSnapshotStore()) {
        self.snapshotStore = snapshotStore
    }

    // MARK: - 1. 事件驱动增量处理 (FSEvents 后续处理)

    func processChangedFiles(source: SourceDescriptor, filePaths: [String]) async -> [CollectedActivity] {
        let root = URL(fileURLWithPath: source.path, isDirectory: true)
        var activities: [CollectedActivity] = []

        for path in filePaths {
            let fileURL = URL(fileURLWithPath: path)
            guard fileURL.pathExtension.lowercased() == "md",
                  !isIgnored(fileURL, root: root, patterns: source.ignorePatterns) else { continue }

            // 检查文件是否存在
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                // 文件被删除：仅更新快照存储，不产生负向证据，不扣减 Mastery
                await snapshotStore.removeSnapshot(sourceID: source.id, filePath: fileURL.path)
                AppLogger.collector.info("Markdown file removed at \(fileURL.path, privacy: .public), snapshot cleared")
                continue
            }

            guard let data = try? Data(contentsOf: fileURL),
                  let currentContent = String(data: data, encoding: .utf8) else { continue }

            let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
            let modifiedAt = (attributes?[.modificationDate] as? Date) ?? .now

            let oldSnapshot = await snapshotStore.snapshot(sourceID: source.id, filePath: fileURL.path)
            let diffResult = MarkdownDiffEngine.diff(oldContent: oldSnapshot?.content ?? "", newContent: currentContent)

            // 无实质内容变动时跳过
            guard diffResult.hasChanges else {
                continue
            }

            // 保存新版本快照
            let newHash = Self.hexDigest(data)
            let newSnapshot = MarkdownSnapshot(
                sourceID: source.id,
                filePath: fileURL.path,
                contentHash: newHash,
                content: currentContent,
                modifiedAt: modifiedAt
            )
            await snapshotStore.saveSnapshot(newSnapshot)

            let relativePath = fileURL.path.replacingOccurrences(of: root.path + "/", with: "")
            let title = extractTitle(from: currentContent, fallback: fileURL.deletingPathExtension().lastPathComponent)

            activities.append(
                CollectedActivity(
                    sourceID: source.id,
                    sourceKind: .markdownDirectory,
                    timestamp: modifiedAt,
                    fingerprint: "\(source.id.uuidString)-\(diffResult.normalizedDiffHash)",
                    title: title,
                    sourceLocator: fileURL.path,
                    summary: "Markdown 增量 · \(relativePath)",
                    excerpt: diffResult.diffExcerpt
                )
            )
        }

        return activities
    }

    // MARK: - 2. 兜底对账扫描 (Reconciliation Scan)

    func scan(source: SourceDescriptor) async throws -> ActivityScanResult {
        let root = URL(fileURLWithPath: source.path, isDirectory: true)
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey, .isHiddenKey]
        let fileURLs = Self.enumeratedFileURLs(at: root, keys: keys)

        var changedPaths: [String] = []
        for fileURL in fileURLs {
            guard fileURL.pathExtension.lowercased() == "md",
                  !isIgnored(fileURL, root: root, patterns: source.ignorePatterns),
                  let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { continue }

            let oldSnapshot = await snapshotStore.snapshot(sourceID: source.id, filePath: fileURL.path)
            guard let data = try? Data(contentsOf: fileURL),
                  let currentContent = String(data: data, encoding: .utf8) else { continue }

            let currentHash = Self.hexDigest(data)
            if oldSnapshot == nil || oldSnapshot?.contentHash != currentHash {
                changedPaths.append(fileURL.path)
            }
        }

        let activities = await processChangedFiles(source: source, filePaths: changedPaths)
        return ActivityScanResult(activities: activities, scannedAt: .now)
    }

    // MARK: - 辅助方法

    private func extractTitle(from content: String, fallback: String) -> String {
        let firstHeading = content
            .split(whereSeparator: \.isNewline)
            .first(where: { $0.hasPrefix("#") })?
            .trimmingCharacters(in: CharacterSet(charactersIn: "# \t"))
        if let firstHeading, !firstHeading.isEmpty {
            return firstHeading
        }
        return fallback
    }

    private nonisolated static func enumeratedFileURLs(at root: URL, keys: [URLResourceKey]) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var fileURLs: [URL] = []
        while let fileURL = enumerator.nextObject() as? URL {
            fileURLs.append(fileURL)
        }
        return fileURLs
    }

    private func isIgnored(_ fileURL: URL, root: URL, patterns: [String]) -> Bool {
        let relative = fileURL.path.replacingOccurrences(of: root.path + "/", with: "")
        let components = relative.split(separator: "/")
        for comp in components {
            if comp.hasPrefix(".") { return true }
        }
        return patterns.contains { pattern in
            !pattern.isEmpty && relative.localizedStandardContains(pattern)
        }
    }

    private static func hexDigest(_ data: Data) -> String {
        SHA256.hash(data: data).map { byte in
            let value = String(byte, radix: 16)
            return value.count == 1 ? "0" + value : value
        }.joined()
    }
}
