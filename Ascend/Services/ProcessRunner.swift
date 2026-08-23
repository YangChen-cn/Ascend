import Darwin
import Foundation

actor ProcessRunner {
    enum ProcessError: LocalizedError, Equatable {
        case unavailable(command: String, reason: String)
        case failed(command: String, terminationStatus: Int32, stderr: String)
        case timedOut(command: String, seconds: TimeInterval)
        case cancelled(command: String)
        case outputLimitExceeded(command: String, maximumBytes: Int)

        var errorDescription: String? {
            switch self {
            case .unavailable(let command, let reason):
                "无法启动命令“\(command)”：\(reason)"
            case .failed(let command, let status, let stderr):
                "命令“\(command)”执行失败（\(status)）：\(stderr.isEmpty ? "未提供错误输出" : stderr)"
            case .timedOut(let command, let seconds):
                "命令“\(command)”在 \(seconds.formatted()) 秒后超时"
            case .cancelled(let command):
                "命令“\(command)”已取消"
            case .outputLimitExceeded(let command, let maximumBytes):
                "命令“\(command)”的输出超过安全上限（\(maximumBytes) 字节）"
            }
        }
    }

    func run(
        executableURL: URL,
        arguments: [String],
        timeout: TimeInterval = 60,
        maximumOutputBytes: Int = 8 * 1_024 * 1_024,
        allowTruncatedOutput: Bool = false
    ) async throws -> String {
        let command = executableURL.lastPathComponent
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let termination = ProcessTermination()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.terminationHandler = { finishedProcess in
            termination.finish(status: finishedProcess.terminationStatus)
        }

        do {
            try process.run()
            // 子进程已继承 Pipe 写端；父进程必须关闭自己的副本，读取端才能在子进程退出后收到 EOF。
            try? stdoutPipe.fileHandleForWriting.close()
            try? stderrPipe.fileHandleForWriting.close()
        } catch {
            throw ProcessError.unavailable(command: command, reason: error.localizedDescription)
        }

        let execution = ProcessExecution(
            process: process,
            stdout: stdoutPipe.fileHandleForReading,
            stderr: stderrPipe.fileHandleForReading,
            termination: termination,
            maximumBytes: maximumOutputBytes
        )

        return try await withTaskCancellationHandler {
            do {
                let result = try await withThrowingTaskGroup(of: ExecutionResult.self) { group in
                    group.addTask {
                        await execution.collect()
                    }
                    group.addTask {
                        try await Task.sleep(for: .seconds(timeout))
                        execution.terminate()
                        throw ProcessError.timedOut(command: command, seconds: timeout)
                    }

                    guard let first = try await group.next() else {
                        throw ProcessError.cancelled(command: command)
                    }
                    group.cancelAll()
                    return first
                }

                guard result.terminationStatus == 0 else {
                    throw ProcessError.failed(
                        command: command,
                        terminationStatus: result.terminationStatus,
                        stderr: result.stderr
                    )
                }
                if (result.stdoutWasTruncated || result.stderrWasTruncated) && !allowTruncatedOutput {
                    throw ProcessError.outputLimitExceeded(
                        command: command,
                        maximumBytes: maximumOutputBytes
                    )
                }
                return result.stdout
            } catch is CancellationError {
                execution.terminate()
                throw ProcessError.cancelled(command: command)
            } catch {
                execution.terminate()
                throw error
            }
        } onCancel: {
            execution.terminate()
        }
    }
}

private struct ExecutionResult: Sendable {
    let stdout: String
    let stderr: String
    let terminationStatus: Int32
    let stdoutWasTruncated: Bool
    let stderrWasTruncated: Bool
}

private final class ProcessExecution: @unchecked Sendable {
    private let process: Process
    private let stdout: StreamCollector
    private let stderr: StreamCollector
    private let termination: ProcessTermination
    private let lock = NSLock()
    private var didRequestTermination = false

    init(
        process: Process,
        stdout: FileHandle,
        stderr: FileHandle,
        termination: ProcessTermination,
        maximumBytes: Int
    ) {
        self.process = process
        self.stdout = StreamCollector(handle: stdout, maximumBytes: maximumBytes)
        self.stderr = StreamCollector(handle: stderr, maximumBytes: maximumBytes)
        self.termination = termination
        self.stdout.startReading()
        self.stderr.startReading()
    }

    func collect() async -> ExecutionResult {
        let terminationStatus = await termination.value()
        let capturedStdout = stdout.finish()
        let capturedStderr = stderr.finish()
        return ExecutionResult(
            stdout: capturedStdout.text,
            stderr: capturedStderr.text,
            terminationStatus: terminationStatus,
            stdoutWasTruncated: capturedStdout.wasTruncated,
            stderrWasTruncated: capturedStderr.wasTruncated
        )
    }

    func terminate() {
        lock.lock()
        guard !didRequestTermination else {
            lock.unlock()
            return
        }
        didRequestTermination = true
        let isRunning = process.isRunning
        let processID = process.processIdentifier
        let descendantIDs = Self.descendants(of: processID)
        lock.unlock()

        guard isRunning else { return }
        descendantIDs.reversed().forEach { Darwin.kill($0, SIGTERM) }
        process.terminate()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.25) { [weak self] in
            descendantIDs.reversed().forEach { Darwin.kill($0, SIGKILL) }
            if let self, self.process.isRunning {
                Darwin.kill(processID, SIGKILL)
            }
        }
    }

    private static func descendants(of parentID: pid_t) -> [pid_t] {
        var result: [pid_t] = []
        var pending = [parentID]
        while let current = pending.popLast() {
            var children = [pid_t](repeating: 0, count: 64)
            let byteCount = proc_listchildpids(
                current,
                &children,
                Int32(children.count * MemoryLayout<pid_t>.stride)
            )
            guard byteCount > 0 else { continue }
            let count = min(Int(byteCount) / MemoryLayout<pid_t>.stride, children.count)
            let validChildren = children.prefix(count).filter { $0 > 0 }
            result.append(contentsOf: validChildren)
            pending.append(contentsOf: validChildren)
        }
        return result
    }

}

private final class ProcessTermination: @unchecked Sendable {
    private let lock = NSLock()
    private var status: Int32?
    private var continuation: CheckedContinuation<Int32, Never>?

    func finish(status: Int32) {
        lock.lock()
        guard self.status == nil else {
            lock.unlock()
            return
        }
        self.status = status
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(returning: status)
    }

    func value() async -> Int32 {
        await withCheckedContinuation { continuation in
            lock.lock()
            if let status {
                lock.unlock()
                continuation.resume(returning: status)
            } else {
                self.continuation = continuation
                lock.unlock()
            }
        }
    }
}

/// Drains a pipe while its child process is running so a full pipe buffer can
/// never block the child. Access to FileHandle and the captured bytes is
/// serialized because a termination callback can race the final drain.
private final class StreamCollector: @unchecked Sendable {
    private let handle: FileHandle
    private let maximumBytes: Int
    private let lock = NSLock()
    private var data = Data()
    private var reachedEOF = false
    private var wasTruncated = false

    init(handle: FileHandle, maximumBytes: Int) {
        self.handle = handle
        self.maximumBytes = maximumBytes
    }

    func startReading() {
        handle.readabilityHandler = { [weak self] readableHandle in
            guard let self else { return }
            lock.lock()
            defer { lock.unlock() }
            guard !reachedEOF else { return }
            let chunk = readableHandle.availableData
            if chunk.isEmpty {
                reachedEOF = true
            } else {
                appendBounded(chunk)
            }
        }
    }

    func finish() -> CapturedStream {
        handle.readabilityHandler = nil
        lock.lock()
        defer {
            lock.unlock()
            try? handle.close()
        }

        if !reachedEOF, let trailing = try? handle.readToEnd() {
            appendBounded(trailing)
        }
        return CapturedStream(
            text: String(decoding: data, as: UTF8.self),
            wasTruncated: wasTruncated
        )
    }

    private func appendBounded(_ chunk: Data) {
        let remaining = max(0, maximumBytes - data.count)
        if remaining > 0 {
            data.append(chunk.prefix(remaining))
        }
        if chunk.count > remaining {
            wasTruncated = true
        }
    }
}

private struct CapturedStream: Sendable {
    let text: String
    let wasTruncated: Bool
}
