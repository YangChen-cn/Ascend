import CryptoKit
import Foundation

actor MarkdownActivityConnector: ActivitySourceConnector {
    private struct CurrentFile: Sendable {
        let path: String
        let contentHash: String
        let content: String
        let modifiedAt: Date
    }

    private let snapshotStore: MarkdownSnapshotStore

    init(snapshotStore: MarkdownSnapshotStore = MarkdownSnapshotStore()) {
        self.snapshotStore = snapshotStore
    }

    // MARK: - FSEvents 增量处理

    func processChangedFiles(source: SourceDescriptor, filePaths: [String]) async -> ActivityScanResult {
        let root = URL(fileURLWithPath: source.path, isDirectory: true)
        let paths = Array(Set(filePaths.map { URL(fileURLWithPath: $0).standardizedFileURL.path })).sorted()
        let snapshots = await snapshotStore.allSnapshots(for: source.id)
        var currentFiles: [String: CurrentFile] = [:]

        for path in paths {
            let fileURL = URL(fileURLWithPath: path)
            guard fileURL.pathExtension.lowercased() == "md",
                  !isIgnored(fileURL, root: root, patterns: source.ignorePatterns),
                  FileManager.default.fileExists(atPath: path),
                  let data = try? Data(contentsOf: fileURL),
                  let content = String(data: data, encoding: .utf8) else { continue }

            let attributes = try? FileManager.default.attributesOfItem(atPath: path)
            currentFiles[path] = CurrentFile(
                path: path,
                contentHash: Self.hexDigest(data),
                content: content,
                modifiedAt: (attributes?[.modificationDate] as? Date) ?? .now
            )
        }

        var mutations: [MarkdownSnapshotMutation] = []
        var renamedPaths = Set<String>()
        var deletedByHash: [String: [String]] = [:]

        for path in paths where currentFiles[path] == nil {
            if let snapshot = snapshots[path] {
                deletedByHash[snapshot.contentHash, default: []].append(path)
            }
        }

        // 同一防抖窗口中，旧路径消失且新路径内容完全相同，只移动快照，不生成学习活动。
        for path in paths where snapshots[path] == nil {
            guard let current = currentFiles[path],
                  var candidates = deletedByHash[current.contentHash],
                  let oldPath = candidates.first else { continue }
            candidates.removeFirst()
            deletedByHash[current.contentHash] = candidates
            renamedPaths.insert(oldPath)
            renamedPaths.insert(path)
            mutations.append(.rename(sourceID: source.id, oldPath: oldPath, newPath: path))
        }

        var activities: [CollectedActivity] = []
        for path in paths where !renamedPaths.contains(path) {
            guard let current = currentFiles[path] else {
                if snapshots[path] != nil {
                    mutations.append(.remove(sourceID: source.id, filePath: path))
                }
                continue
            }

            let oldSnapshot = snapshots[path]
            let diffResult = MarkdownDiffEngine.diff(
                oldContent: oldSnapshot?.content ?? "",
                newContent: current.content
            )
            guard diffResult.hasChanges else { continue }

            let snapshot = MarkdownSnapshot(
                sourceID: source.id,
                filePath: path,
                contentHash: current.contentHash,
                content: current.content,
                modifiedAt: current.modifiedAt
            )
            mutations.append(.save(snapshot))

            let relativePath = path.replacingOccurrences(of: root.path + "/", with: "")
            let title = extractTitle(
                from: current.content,
                fallback: URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            )
            let eventFingerprint = MarkdownDiffEngine.hexDigest(
                [
                    source.id.uuidString,
                    path,
                    oldSnapshot?.contentHash ?? "new",
                    current.contentHash,
                    diffResult.normalizedDiffHash
                ].joined(separator: "|")
            )

            activities.append(
                CollectedActivity(
                    sourceID: source.id,
                    sourceKind: .markdownDirectory,
                    timestamp: current.modifiedAt,
                    fingerprint: "markdown-event-\(eventFingerprint)",
                    contentChangeHash: diffResult.normalizedDiffHash,
                    title: title,
                    sourceLocator: path,
                    summary: "Markdown 增量 · \(relativePath)",
                    excerpt: diffResult.diffExcerpt
                )
            )
        }

        return ActivityScanResult(
            activities: activities,
            markdownSnapshotMutations: mutations
        )
    }

    func commitSnapshotMutations(_ mutations: [MarkdownSnapshotMutation]) async {
        await snapshotStore.apply(mutations)
    }

    // MARK: - 兜底对账扫描

    func scan(source: SourceDescriptor) async throws -> ActivityScanResult {
        let root = URL(fileURLWithPath: source.path, isDirectory: true)
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey, .isHiddenKey]
        let fileURLs = Self.enumeratedFileURLs(at: root, keys: keys)
        let snapshots = await snapshotStore.allSnapshots(for: source.id)
        var changedPaths: [String] = []
        var currentPaths = Set<String>()

        for fileURL in fileURLs {
            guard fileURL.pathExtension.lowercased() == "md",
                  !isIgnored(fileURL, root: root, patterns: source.ignorePatterns),
                  let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { continue }

            let path = fileURL.standardizedFileURL.path
            currentPaths.insert(path)
            guard let data = try? Data(contentsOf: fileURL) else { continue }
            if snapshots[path]?.contentHash != Self.hexDigest(data) {
                changedPaths.append(path)
            }
        }

        changedPaths.append(contentsOf: snapshots.keys.filter { !currentPaths.contains($0) })
        let result = await processChangedFiles(source: source, filePaths: changedPaths)
        return ActivityScanResult(
            activities: result.activities,
            scannedAt: .now,
            markdownSnapshotMutations: result.markdownSnapshotMutations
        )
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
        if components.contains(where: { $0.hasPrefix(".") }) { return true }
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
