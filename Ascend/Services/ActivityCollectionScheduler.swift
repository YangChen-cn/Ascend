import Foundation

actor ActivityCollectionScheduler {
    typealias ScanOperation = @MainActor @Sendable () async -> Void

    private var loopTask: Task<Void, Never>?
    private(set) var isRunning = false

    func start(interval: Duration, scan: @escaping ScanOperation) {
        guard loopTask == nil else { return }
        isRunning = true
        loopTask = Task { [weak self] in
            await scan()
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    break
                }
                guard !Task.isCancelled else { break }
                await scan()
            }
            await self?.didFinishLoop()
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        isRunning = false
    }

    private func didFinishLoop() {
        loopTask = nil
        isRunning = false
    }
}
