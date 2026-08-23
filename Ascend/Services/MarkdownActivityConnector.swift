import CryptoKit
import Foundation

actor MarkdownActivityConnector: ActivitySourceConnector {
    func scan(source: SourceDescriptor) async throws -> [CollectedActivity] {
        let root = URL(fileURLWithPath: source.path, isDirectory: true)
        let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey, .isHiddenKey]
        let fileURLs = Self.enumeratedFileURLs(at: root, keys: keys)

        var activities: [CollectedActivity] = []
        for fileURL in fileURLs {
            guard fileURL.pathExtension.lowercased() == "md",
                  !isIgnored(fileURL, root: root, patterns: source.ignorePatterns),
                  let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let modifiedAt = values.contentModificationDate,
                  modifiedAt > (source.lastScannedAt ?? .distantPast),
                  let data = try? Data(contentsOf: fileURL),
                  let content = String(data: data, encoding: .utf8) else { continue }

            let relativePath = fileURL.path.replacing(root.path + "/", with: "")
            let fingerprint = Self.hexDigest(data)
            let title = content
                .split(whereSeparator: \.isNewline)
                .first(where: { $0.hasPrefix("#") })?
                .trimmingCharacters(in: CharacterSet(charactersIn: "# "))
                ?? fileURL.deletingPathExtension().lastPathComponent
            activities.append(
                CollectedActivity(
                    sourceID: source.id,
                    sourceKind: .markdownDirectory,
                    timestamp: modifiedAt,
                    fingerprint: fingerprint,
                    title: String(title),
                    sourceLocator: fileURL.path,
                    summary: "Markdown 更新 · \(relativePath)",
                    excerpt: String(content.prefix(AppConstants.maximumAuditExcerptLength))
                )
            )
        }
        return activities
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
        let relative = fileURL.path.replacing(root.path + "/", with: "")
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
