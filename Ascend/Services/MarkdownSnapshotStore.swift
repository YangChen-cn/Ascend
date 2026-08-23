import Foundation

actor MarkdownSnapshotStore {
    private var inMemoryCache: [UUID: [String: MarkdownSnapshot]] = [:]
    private let storageDirectoryURL: URL?
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(storageDirectoryURL: URL? = nil) {
        if let storageDirectoryURL {
            self.storageDirectoryURL = storageDirectoryURL
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            self.storageDirectoryURL = appSupport?.appendingPathComponent("Ascend/MarkdownSnapshots", isDirectory: true)
        }
        if let dir = self.storageDirectoryURL {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    func snapshot(sourceID: UUID, filePath: String) -> MarkdownSnapshot? {
        loadCacheIfNeeded(for: sourceID)
        let normalized = normalize(filePath)
        return inMemoryCache[sourceID]?[normalized]
    }

    func allSnapshots(for sourceID: UUID) -> [String: MarkdownSnapshot] {
        loadCacheIfNeeded(for: sourceID)
        return inMemoryCache[sourceID] ?? [:]
    }

    func saveSnapshot(_ snapshot: MarkdownSnapshot) {
        loadCacheIfNeeded(for: snapshot.sourceID)
        let normalized = normalize(snapshot.filePath)
        let normalizedSnapshot = MarkdownSnapshot(
            sourceID: snapshot.sourceID,
            filePath: normalized,
            contentHash: snapshot.contentHash,
            content: snapshot.content,
            modifiedAt: snapshot.modifiedAt
        )
        inMemoryCache[snapshot.sourceID, default: [:]][normalized] = normalizedSnapshot
        persistCache(for: snapshot.sourceID)
    }

    func saveSnapshots(_ snapshots: [MarkdownSnapshot]) {
        for s in snapshots {
            loadCacheIfNeeded(for: s.sourceID)
            let normalized = normalize(s.filePath)
            let normalizedSnapshot = MarkdownSnapshot(
                sourceID: s.sourceID,
                filePath: normalized,
                contentHash: s.contentHash,
                content: s.content,
                modifiedAt: s.modifiedAt
            )
            inMemoryCache[s.sourceID, default: [:]][normalized] = normalizedSnapshot
        }
        if let sourceID = snapshots.first?.sourceID {
            persistCache(for: sourceID)
        }
    }

    func removeSnapshot(sourceID: UUID, filePath: String) {
        loadCacheIfNeeded(for: sourceID)
        let normalized = normalize(filePath)
        inMemoryCache[sourceID]?.removeValue(forKey: normalized)
        persistCache(for: sourceID)
    }

    func renameSnapshot(sourceID: UUID, from oldPath: String, to newPath: String) {
        loadCacheIfNeeded(for: sourceID)
        let normalizedOld = normalize(oldPath)
        let normalizedNew = normalize(newPath)
        guard let existing = inMemoryCache[sourceID]?.removeValue(forKey: normalizedOld) else { return }
        let renamed = MarkdownSnapshot(
            sourceID: sourceID,
            filePath: normalizedNew,
            contentHash: existing.contentHash,
            content: existing.content,
            modifiedAt: .now
        )
        inMemoryCache[sourceID, default: [:]][normalizedNew] = renamed
        persistCache(for: sourceID)
    }

    func apply(_ mutations: [MarkdownSnapshotMutation]) {
        guard !mutations.isEmpty else { return }
        var affectedSourceIDs = Set<UUID>()

        for mutation in mutations {
            switch mutation {
            case .save(let snapshot):
                loadCacheIfNeeded(for: snapshot.sourceID)
                let normalized = normalize(snapshot.filePath)
                inMemoryCache[snapshot.sourceID, default: [:]][normalized] = MarkdownSnapshot(
                    sourceID: snapshot.sourceID,
                    filePath: normalized,
                    contentHash: snapshot.contentHash,
                    content: snapshot.content,
                    modifiedAt: snapshot.modifiedAt
                )
                affectedSourceIDs.insert(snapshot.sourceID)
            case .remove(let sourceID, let filePath):
                loadCacheIfNeeded(for: sourceID)
                inMemoryCache[sourceID]?.removeValue(forKey: normalize(filePath))
                affectedSourceIDs.insert(sourceID)
            case .rename(let sourceID, let oldPath, let newPath):
                loadCacheIfNeeded(for: sourceID)
                let normalizedOld = normalize(oldPath)
                let normalizedNew = normalize(newPath)
                guard let existing = inMemoryCache[sourceID]?.removeValue(forKey: normalizedOld) else { continue }
                inMemoryCache[sourceID, default: [:]][normalizedNew] = MarkdownSnapshot(
                    sourceID: sourceID,
                    filePath: normalizedNew,
                    contentHash: existing.contentHash,
                    content: existing.content,
                    modifiedAt: existing.modifiedAt
                )
                affectedSourceIDs.insert(sourceID)
            }
        }

        affectedSourceIDs.forEach(persistCache)
    }

    func clearSnapshots(for sourceID: UUID) {
        inMemoryCache[sourceID] = [:]
        if let fileURL = fileURL(for: sourceID) {
            try? fileManager.removeItem(at: fileURL)
        }
    }

    // MARK: - 内部辅助

    private func normalize(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private func fileURL(for sourceID: UUID) -> URL? {
        storageDirectoryURL?.appendingPathComponent("\(sourceID.uuidString).json")
    }

    private func loadCacheIfNeeded(for sourceID: UUID) {
        if inMemoryCache[sourceID] != nil { return }
        guard let url = fileURL(for: sourceID),
              fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let list = try? decoder.decode([MarkdownSnapshot].self, from: data) else {
            inMemoryCache[sourceID] = [:]
            return
        }
        var map: [String: MarkdownSnapshot] = [:]
        for item in list {
            map[normalize(item.filePath)] = item
        }
        inMemoryCache[sourceID] = map
    }

    private func persistCache(for sourceID: UUID) {
        guard let url = fileURL(for: sourceID),
              let map = inMemoryCache[sourceID] else { return }
        let list = Array(map.values)
        if let data = try? encoder.encode(list) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
