import Foundation

actor MarkdownEventDebouncer {
    private let debounceDuration: Duration
    private var pendingPathsBySource: [UUID: Set<String>] = [:]
    private var activeDebounceTasks: [UUID: Task<Void, Never>] = [:]

    init(debounceDuration: Duration = .seconds(1.5)) {
        self.debounceDuration = debounceDuration
    }

    func enqueue(
        sourceID: UUID,
        paths: [String],
        onFlush: @escaping @Sendable (UUID, [String]) async -> Void
    ) {
        let normalizedPaths = paths.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
        pendingPathsBySource[sourceID, default: []].formUnion(normalizedPaths)

        // 取消该来源的旧定时器，重新计时（防抖）
        activeDebounceTasks[sourceID]?.cancel()

        activeDebounceTasks[sourceID] = Task { [weak self, debounceDuration] in
            do {
                try await Task.sleep(for: debounceDuration)
            } catch {
                return // 被取消，说明用户继续在编辑该文件
            }

            guard !Task.isCancelled, let self else { return }
            await self.flush(sourceID: sourceID, onFlush: onFlush)
        }
    }

    func flush(sourceID: UUID, onFlush: @escaping @Sendable (UUID, [String]) async -> Void) async {
        activeDebounceTasks[sourceID]?.cancel()
        activeDebounceTasks.removeValue(forKey: sourceID)

        guard let paths = pendingPathsBySource.removeValue(forKey: sourceID), !paths.isEmpty else { return }
        await onFlush(sourceID, Array(paths))
    }

    func flushAll(onFlush: @escaping @Sendable (UUID, [String]) async -> Void) async {
        for sourceID in Array(pendingPathsBySource.keys) {
            await flush(sourceID: sourceID, onFlush: onFlush)
        }
    }

    func cancel(for sourceID: UUID) {
        activeDebounceTasks[sourceID]?.cancel()
        activeDebounceTasks.removeValue(forKey: sourceID)
        pendingPathsBySource.removeValue(forKey: sourceID)
    }
}
