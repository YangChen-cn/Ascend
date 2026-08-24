import Foundation
import XCTest
@testable import Ascend

@MainActor
final class RemoteGitRepositoryConnectorTests: XCTestCase {
    func testFetchUsesUpdatedUpstreamWhenLocalHeadIsStale() async throws {
        let fixture = try await makeRemoteFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let connector = RemoteGitRepositoryConnector()
        let initialSource = SourceDescriptor(
            name: "Remote Notes",
            kind: .remoteGitRepository,
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

    func testCommitWithMarkdownAndCodeProducesDistinctUnderstandingAndPracticeActivities() async throws {
        let fixture = try await makeRemoteFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let connector = RemoteGitRepositoryConnector()
        let source = SourceDescriptor(name: "Mixed Repo", kind: .remoteGitRepository, path: fixture.reader.path)
        let initialScan = try await connector.scan(source: source)
        let initialCursor = try XCTUnwrap(initialScan.nextCursor)

        try "# Linux\n我理解了 waitpid 如何回收子进程。\n".write(
            to: fixture.writer.appendingPathComponent("linux.md"), atomically: true, encoding: .utf8
        )
        try "#include <sys/wait.h>\nint reap(int pid) { return waitpid(pid, 0, 0); }\n".write(
            to: fixture.writer.appendingPathComponent("process.c"), atomically: true, encoding: .utf8
        )
        try "let val = 42\n".write(
            to: fixture.writer.appendingPathComponent("Test.swift"), atomically: true, encoding: .utf8
        )
        try await git(["add", "linux.md", "process.c", "Test.swift"], in: fixture.writer)
        try await git(["commit", "-m", "理解并实践 waitpid"], in: fixture.writer)
        try await git(["push"], in: fixture.writer)

        let result = try await connector.scan(
            source: SourceDescriptor(
                id: source.id,
                name: source.name,
                kind: source.kind,
                path: source.path,
                lastCursor: initialCursor
            )
        )

        XCTAssertEqual(result.activities.count, 2)
        XCTAssertEqual(result.activities.count { $0.summary.hasPrefix("[Markdown 学习笔记]") }, 1)
        let codeActivity = try XCTUnwrap(result.activities.first { $0.summary.hasPrefix("[代码实践]") })
        XCTAssertTrue(codeActivity.excerpt.contains("process.c"))
        XCTAssertTrue(codeActivity.excerpt.contains("Test.swift"))
        XCTAssertEqual(Set(result.activities.map(\.contentChangeHash)).count, 2)
    }

    func testThreeUnseenCommitsAreCollectedInChronologicalOrderAndNotRepeated() async throws {
        let fixture = try await makeRemoteFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let connector = RemoteGitRepositoryConnector()
        let source = SourceDescriptor(
            name: "Ordered Repo",
            kind: .remoteGitRepository,
            path: fixture.reader.path,
            analyzeMarkdown: false,
            analyzeCode: true
        )
        let initialScan = try await connector.scan(source: source)
        let initialCursor = try XCTUnwrap(initialScan.nextCursor)

        for index in 1...3 {
            try "int value(void) { return \(index); }\n".write(
                to: fixture.writer.appendingPathComponent("value.c"), atomically: true, encoding: .utf8
            )
            try await git(["add", "value.c"], in: fixture.writer)
            try await git(["commit", "-m", "实践步骤 \(index)"], in: fixture.writer)
        }
        try await git(["push"], in: fixture.writer)

        let incrementalSource = SourceDescriptor(
            id: source.id,
            name: source.name,
            kind: source.kind,
            path: source.path,
            analyzeMarkdown: false,
            analyzeCode: true,
            lastCursor: initialCursor
        )
        let firstResult = try await connector.scan(source: incrementalSource)
        XCTAssertEqual(firstResult.activities.map(\.title), ["实践步骤 1", "实践步骤 2", "实践步骤 3"])

        let repeated = try await connector.scan(
            source: SourceDescriptor(
                id: source.id,
                name: source.name,
                kind: source.kind,
                path: source.path,
                analyzeMarkdown: false,
                analyzeCode: true,
                lastCursor: firstResult.nextCursor
            )
        )
        XCTAssertTrue(repeated.activities.isEmpty)
        XCTAssertEqual(repeated.nextCursor, firstResult.nextCursor)
    }

    func testCodeWhitelistAndAnalysisToggles() async throws {
        let fixture = try await makeRemoteFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let connector = RemoteGitRepositoryConnector()
        let sourceID = UUID()
        let initialScan = try await connector.scan(
            source: SourceDescriptor(
                id: sourceID,
                name: "Toggle Repo",
                kind: .remoteGitRepository,
                path: fixture.reader.path
            )
        )
        let initialCursor = try XCTUnwrap(initialScan.nextCursor)

        try "# pipe\n理解管道读写端。\n".write(
            to: fixture.writer.appendingPathComponent("pipe.md"), atomically: true, encoding: .utf8
        )
        try "int pipe_demo(void) { return 1; }\n".write(
            to: fixture.writer.appendingPathComponent("pipe.c"), atomically: true, encoding: .utf8
        )
        try "binary metadata".write(
            to: fixture.writer.appendingPathComponent("artifact.dat"), atomically: true, encoding: .utf8
        )
        try await git(["add", "pipe.md", "pipe.c", "artifact.dat"], in: fixture.writer)
        try await git(["commit", "-m", "理解并实现 pipe 及产物"], in: fixture.writer)
        try await git(["push"], in: fixture.writer)

        // 1. Markdown 独立开关
        let markdownOnly = try await connector.scan(
            source: SourceDescriptor(
                id: sourceID,
                name: "Toggle Repo",
                kind: .remoteGitRepository,
                path: fixture.reader.path,
                analyzeMarkdown: true,
                analyzeCode: false,
                lastCursor: initialCursor
            )
        )
        XCTAssertEqual(markdownOnly.activities.count, 1)
        XCTAssertTrue(markdownOnly.activities[0].summary.hasPrefix("[Markdown 学习笔记]"))

        // 2. Code 独立开关与白名单过滤（忽略 .dat）
        let codeOnly = try await connector.scan(
            source: SourceDescriptor(
                id: sourceID,
                name: "Toggle Repo",
                kind: .remoteGitRepository,
                path: fixture.reader.path,
                analyzeMarkdown: false,
                analyzeCode: true,
                lastCursor: initialCursor
            )
        )
        XCTAssertEqual(codeOnly.activities.count, 1)
        XCTAssertTrue(codeOnly.activities[0].summary.hasPrefix("[代码实践]"))
        XCTAssertFalse(codeOnly.activities[0].excerpt.contains("artifact.dat"))
    }

    func testFormattingOnlyDiffIsMarkedLowInformation() {
        let diff = """
        diff --git a/main.c b/main.c
        --- a/main.c
        +++ b/main.c
        @@ -1 +1 @@
        -int main(){return 0;}
        +int main() { return 0; }
        """

        let assessment = CodeDiffClassifier.assess(diff)

        XCTAssertFalse(assessment.isSubstantive)
        XCTAssertEqual(assessment.reason, "仅格式化或代码移动")
    }

    func testFetchFailureDoesNotAdvancePersistedCursor() async throws {
        let fixture = try await makeRemoteFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let initialCursor = try await git(["rev-parse", "HEAD"], in: fixture.reader)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        try await git(
            ["remote", "set-url", "origin", fixture.root.appendingPathComponent("missing.git").path],
            in: fixture.reader
        )

        let container = PersistenceController.makeContainer(inMemory: true)
        let appState = AppState(modelContainer: container)
        let source = SourceConfiguration(
            name: "Broken Remote",
            kind: .remoteGitRepository,
            path: fixture.reader.path
        )
        source.lastCursor = initialCursor
        container.mainContext.insert(source)
        try container.mainContext.save()
        appState.reload()

        do {
            try await appState.scanSources()
            XCTFail("Expected fetch failure")
        } catch {
            XCTAssertEqual(source.lastCursor, initialCursor)
            XCTAssertNotNil(source.lastSyncError)
            XCTAssertTrue(source.lastSyncError?.contains("git") == true)
        }
    }

    func testPersistedCursorPreventsDuplicateActivitiesAfterAppStateReload() async throws {
        let fixture = try await makeRemoteFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let container = PersistenceController.makeContainer(inMemory: true)
        let source = SourceConfiguration(
            name: "Restart Repo",
            kind: .remoteGitRepository,
            path: fixture.reader.path
        )
        container.mainContext.insert(source)
        try container.mainContext.save()

        let firstState = AppState(modelContainer: container)
        try await firstState.scanSources()
        let firstCount = firstState.activityFeedTotalCount
        let persistedCursor = try XCTUnwrap(source.lastCursor)

        let reloadedState = AppState(modelContainer: container)
        try await reloadedState.scanSources()

        XCTAssertEqual(reloadedState.activityFeedTotalCount, firstCount)
        XCTAssertEqual(source.lastCursor, persistedCursor)
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
