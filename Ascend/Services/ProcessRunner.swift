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
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw ProcessError.unavailable(command: command, reason: error.localizedDescription)
        }

        let execution = ProcessExecution(
            process: process,
            stdout: stdoutPipe.fileHandleForReading,
            stderr: stderrPipe.fileHandleForReading
        )

        return try await withTaskCancellationHandler {
            do {
                let result = try await withThrowingTaskGroup(of: ExecutionResult.self) { group in
                    group.addTask {
                        await execution.collect(maximumBytes: maximumOutputBytes)
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
    private let stdout: FileHandle
    private let stderr: FileHandle
    private let lock = NSLock()
    private var didRequestTermination = false

    init(process: Process, stdout: FileHandle, stderr: FileHandle) {
        self.process = process
        self.stdout = stdout
        self.stderr = stderr
    }

    func collect(maximumBytes: Int) async -> ExecutionResult {
        async let stdoutResult = Self.read(stdout, maximumBytes: maximumBytes)
        async let stderrResult = Self.read(stderr, maximumBytes: maximumBytes)
        process.waitUntilExit()
        let (capturedStdout, capturedStderr) = await (stdoutResult, stderrResult)
        return ExecutionResult(
            stdout: capturedStdout.text,
            stderr: capturedStderr.text,
            terminationStatus: process.terminationStatus,
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

    private static func read(_ handle: FileHandle, maximumBytes: Int) async -> CapturedStream {
        await Task.detached(priority: .utility) {
            var data = Data()
            var wasTruncated = false
            while true {
                let chunk = handle.readData(ofLength: 16 * 1_024)
                guard !chunk.isEmpty else { break }
                let remaining = maximumBytes - data.count
                if remaining > 0 {
                    data.append(chunk.prefix(remaining))
                }
                if chunk.count > remaining {
                    wasTruncated = true
                }
            }
            return CapturedStream(
                text: String(decoding: data, as: UTF8.self),
                wasTruncated: wasTruncated
            )
        }.value
    }
}

private struct CapturedStream: Sendable {
    let text: String
    let wasTruncated: Bool
}
