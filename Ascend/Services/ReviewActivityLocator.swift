import Foundation

struct ReviewActivityLocator: Sendable {
    static func markdownFileURL(from locator: String) -> URL? {
        let trimmed = locator.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if !trimmed.contains("#") {
            let directURL = URL(fileURLWithPath: trimmed).standardizedFileURL
            return directURL.pathExtension.lowercased() == "md" ? directURL : nil
        }

        let parts = trimmed.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let repositoryURL = URL(fileURLWithPath: String(parts[0])).standardizedFileURL
        let revisionAndPath = String(parts[1])
        guard let separator = revisionAndPath.firstIndex(of: ":") else { return nil }

        let relativePath = String(revisionAndPath[revisionAndPath.index(after: separator)...])
        guard !relativePath.isEmpty else { return nil }
        let fileURL = repositoryURL.appending(path: relativePath).standardizedFileURL
        let repositoryPrefix = repositoryURL.path.hasSuffix("/") ? repositoryURL.path : repositoryURL.path + "/"
        guard fileURL.path.hasPrefix(repositoryPrefix), fileURL.pathExtension.lowercased() == "md" else {
            return nil
        }
        return fileURL
    }

    static func isMarkdownNote(_ activity: ActivityEvent) -> Bool {
        markdownFileURL(from: activity.sourceLocator) != nil
    }

    static func markdownDisplayName(for activity: ActivityEvent) -> String? {
        markdownFileURL(from: activity.sourceLocator)?.lastPathComponent
    }
}
