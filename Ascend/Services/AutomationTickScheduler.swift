import Foundation

actor AutomationTickScheduler {
    typealias TickOperation = @MainActor @Sendable () async -> Void

    private var loopTask: Task<Void, Never>?

    func start(interval: Duration, tick: @escaping TickOperation) {
        guard loopTask == nil else { return }
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: interval)
                } catch {
                    break
                }
                guard !Task.isCancelled else { break }
                await tick()
            }
            await self?.didFinishLoop()
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
    }

    private func didFinishLoop() {
        loopTask = nil
    }
}
