import Foundation
import XCTest
@testable import Ascend

final class RemoteGitMarkdownConnectorTests: XCTestCase {
    func testFetchUsesUpdatedUpstreamWhenLocalHeadIsStale() async throws {
        let fixture = try await makeRemoteFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let connector = RemoteGitMarkdownConnector()
        let initialSource = SourceDescriptor(
            name: "Remote Notes",
            kind: .remoteGitMarkdown,
            path: fixture.reader.path
        )
        let initial = try await connector.scan(source: initialSource)
        let initialCursor = try XCTUnwrap(initial.nextCursor)

        let noteURL = fixture.writer.appendingPathComponent("linux.md")
        try "# Linux\nfork 创建子进程。\n\n## pipe\npipe 用于父子进程通信。".write(
            to: noteURL,
            atomically: true,
            encoding: .utf8
        )
        try await git(["add", "linux.md"], in: fixture.writer)
        try await git(["commit", "-m", "补充 pipe 笔记"], in: fixture.writer)
        try await git(["push"], in: fixture.writer)

        let staleLocalHead = try await git(["rev-parse", "HEAD"], in: fixture.reader)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(staleLocalHead, initialCursor)

        let incrementalSource = SourceDescriptor(
            id: initialSource.id,
            name: initialSource.name,
            kind: initialSource.kind,
            path: initialSource.path,
            lastCursor: initialCursor
        )
        let incremental = try await connector.scan(source: incrementalSource)
        let remoteTrackingSHA = try await git(["rev-parse", "origin/main"], in: fixture.reader)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        XCTAssertEqual(incremental.nextCursor, remoteTrackingSHA)
        XCTAssertNotEqual(incremental.nextCursor, staleLocalHead)
        XCTAssertEqual(incremental.activities.count, 1)
        XCTAssertEqual(incremental.activities.first?.title, "补充 pipe 笔记")
        XCTAssertNotNil(incremental.activities.first?.contentChangeHash)
    }

    func testFetchFailureIsNotSilentlyIgnored() async throws {
        let fixture = try await makeRemoteFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        try await git(["remote", "set-url", "origin", fixture.root.appendingPathComponent("missing.git").path], in: fixture.reader)

        let connector = RemoteGitMarkdownConnector()
        let source = SourceDescriptor(name: "Broken Remote", kind: .remoteGitMarkdown, path: fixture.reader.path)

        do {
            _ = try await connector.scan(source: source)
            XCTFail("Expected fetch failure")
        } catch let error as ProcessRunner.ProcessError {
            guard case .failed(let command, _, let stderr) = error else {
                return XCTFail("Expected process failure, got \(error)")
            }
            XCTAssertEqual(command, "git")
            XCTAssertFalse(stderr.isEmpty)
        }
    }

    private struct RemoteFixture {
        let root: URL
        let writer: URL
        let reader: URL
    }

    private func makeRemoteFixture() async throws -> RemoteFixture {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let remote = root.appendingPathComponent("remote.git")
        let writer = root.appendingPathComponent("writer")
        let reader = root.appendingPathComponent("reader")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        try await git(["init", "--bare", "--initial-branch=main", remote.path], in: root)
        try await git(["init", "--initial-branch=main", writer.path], in: root)
        try await git(["config", "user.email", "ascend-tests@example.invalid"], in: writer)
        try await git(["config", "user.name", "Ascend Tests"], in: writer)
        try "# Linux\nfork 创建子进程。".write(
            to: writer.appendingPathComponent("linux.md"),
            atomically: true,
            encoding: .utf8
        )
        try await git(["add", "linux.md"], in: writer)
        try await git(["commit", "-m", "初始 Linux 笔记"], in: writer)
        try await git(["remote", "add", "origin", remote.path], in: writer)
        try await git(["push", "-u", "origin", "main"], in: writer)
        try await git(["clone", remote.path, reader.path], in: root)
        return RemoteFixture(root: root, writer: writer, reader: reader)
    }

    @discardableResult
    private func git(_ arguments: [String], in directory: URL) async throws -> String {
        try await ProcessRunner().run(
            executableURL: URL(fileURLWithPath: "/usr/bin/git"),
            arguments: ["-C", directory.path] + arguments,
            timeout: 30
        )
    }
}
