import XCTest
@testable import Ascend

final class ProcessRunnerTests: XCTestCase {
    private let shellURL = URL(fileURLWithPath: "/bin/sh")

    func testReadsStdoutAndStderrWhileProcessIsRunningWithoutDeadlock() async throws {
        let runner = ProcessRunner()
        let output = try await runner.run(
            executableURL: shellURL,
            arguments: ["-c", "i=0; while [ $i -lt 12000 ]; do echo output-line; echo error-line >&2; i=$((i+1)); done"],
            timeout: 10,
            maximumOutputBytes: 1_024 * 1_024
        )

        XCTAssertTrue(output.hasPrefix("output-line"))
        XCTAssertGreaterThan(output.count, 100_000)
    }

    func testFailurePreservesTerminationStatusAndStderr() async {
        let runner = ProcessRunner()
        do {
            _ = try await runner.run(
                executableURL: shellURL,
                arguments: ["-c", "echo precise-error >&2; exit 23"]
            )
            XCTFail("Expected process failure")
        } catch let error as ProcessRunner.ProcessError {
            guard case .failed(let command, let status, let stderr) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(command, "sh")
            XCTAssertEqual(status, 23)
            XCTAssertTrue(stderr.contains("precise-error"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTimeoutTerminatesProcess() async {
        let runner = ProcessRunner()
        let clock = ContinuousClock()
        let startedAt = clock.now
        do {
            _ = try await runner.run(
                executableURL: shellURL,
                arguments: ["-c", "sleep 5"],
                timeout: 0.05
            )
            XCTFail("Expected timeout")
        } catch let error as ProcessRunner.ProcessError {
            guard case .timedOut = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertLessThan(startedAt.duration(to: clock.now), .seconds(1))
    }

    func testCancellationTerminatesProcess() async {
        let runner = ProcessRunner()
        let executableURL = URL(fileURLWithPath: "/bin/sh")
        let task = Task {
            try await runner.run(
                executableURL: executableURL,
                arguments: ["-c", "sleep 5"],
                timeout: 10
            )
        }
        try? await Task.sleep(for: .milliseconds(50))
        let clock = ContinuousClock()
        let startedAt = clock.now
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch let error as ProcessRunner.ProcessError {
            guard case .cancelled = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertLessThan(startedAt.duration(to: clock.now), .seconds(1))
    }

    func testOutputLimitFailsInsteadOfReturningPartialDataByDefault() async {
        let runner = ProcessRunner()
        do {
            _ = try await runner.run(
                executableURL: shellURL,
                arguments: ["-c", "printf 1234567890"],
                maximumOutputBytes: 4
            )
            XCTFail("Expected output limit failure")
        } catch let error as ProcessRunner.ProcessError {
            guard case .outputLimitExceeded(_, let maximumBytes) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(maximumBytes, 4)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testStderrIsAlsoBounded() async {
        let runner = ProcessRunner()
        do {
            _ = try await runner.run(
                executableURL: shellURL,
                arguments: ["-c", "printf 1234567890 >&2"],
                maximumOutputBytes: 4
            )
            XCTFail("Expected stderr output limit failure")
        } catch let error as ProcessRunner.ProcessError {
            guard case .outputLimitExceeded = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
