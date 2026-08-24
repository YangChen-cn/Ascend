import CryptoKit
import SwiftData
import XCTest
@testable import Ascend

final class MarkdownPipelineTests: XCTestCase {

    // MARK: - 1. Markdown Diff 引擎测试

    func testMarkdownDiffEngineBrandNewFile() {
        let content = """
        # FreeRTOS 任务调度
        FreeRTOS 支持抢占式优先级调度与时间片轮转。
        """
        let result = MarkdownDiffEngine.diff(oldContent: "", newContent: content)

        XCTAssertTrue(result.hasChanges)
        XCTAssertEqual(result.addedCount, 1)
        XCTAssertEqual(result.modifiedCount, 0)
        XCTAssertFalse(result.normalizedDiffHash.isEmpty)
        XCTAssertTrue(result.diffExcerpt.contains("FreeRTOS 任务调度"))
    }

    func testMarkdownDiffEngineSectionAdded() {
        let oldContent = """
        # Linux 进程
        fork 创建子进程。
        """
        let newContent = """
        # Linux 进程
        fork 创建子进程。

        ## waitpid 系统调用
        + waitpid 等待特定子进程退出，防止产生僵尸进程。
        """
        let result = MarkdownDiffEngine.diff(oldContent: oldContent, newContent: newContent)

        XCTAssertTrue(result.hasChanges)
        XCTAssertEqual(result.addedCount, 1)
        XCTAssertTrue(result.diffExcerpt.contains("[新增章节]"))
        XCTAssertTrue(result.diffExcerpt.contains("waitpid"))
    }

    func testMarkdownDiffEngineSectionModified() {
        let oldContent = """
        # 虚拟内存
        虚拟内存会完全复制所有物理内存页。
        """
        let newContent = """
        # 虚拟内存
        虚拟内存通过写时复制（Copy-On-Write, COW）机制延迟物理页的实际复制，大幅降低 fork 时的开销。
        """
        let result = MarkdownDiffEngine.diff(oldContent: oldContent, newContent: newContent)

        XCTAssertTrue(result.hasChanges)
        XCTAssertEqual(result.modifiedCount, 1)
        XCTAssertTrue(result.diffExcerpt.contains("[章节修订]"))
        XCTAssertTrue(result.diffExcerpt.contains("写时复制"))
    }

    func testMarkdownDiffEngineNoChanges() {
        let content = """
        # 编译优化
        -O2 启用大部分安全的代码优化选项。
        """
        let result = MarkdownDiffEngine.diff(oldContent: content, newContent: content)

        XCTAssertFalse(result.hasChanges)
        XCTAssertEqual(result.addedCount, 0)
        XCTAssertEqual(result.modifiedCount, 0)
        XCTAssertEqual(result.diffExcerpt, "")
    }

    func testMarkdownDiffEngineNormalizedHashStability() {
        let text1 = "   Linux   Kernel   Modules   \n\n   insmod   加载模块   "
        let text2 = "linux kernel modules\ninsmod 加载模块"

        let norm1 = MarkdownDiffEngine.normalizedText(text1)
        let norm2 = MarkdownDiffEngine.normalizedText(text2)

        XCTAssertEqual(norm1, norm2)
        XCTAssertEqual(MarkdownDiffEngine.hexDigest(norm1), MarkdownDiffEngine.hexDigest(norm2))
    }

    func testHeadingParserIgnoresPreprocessorDirective() {
        let content = """
        # C 语言接口
        #include <sys/types.h>
        fork 的声明来自 unistd.h。

        ## 进程创建
        fork 创建子进程。
        """

        let headings = MarkdownDiffEngine.parseSections(content).map(\.heading)

        XCTAssertEqual(headings, ["# C 语言接口", "## 进程创建"])
    }

    func testHeadingParserIgnoresHeadingLikeLinesInsideFencedCode() {
        let content = """
        # Markdown 语法
        ```c
        #include <stdio.h>
        # 这不是 Markdown 标题
        ```

        ## 正常标题
        正文。

        ~~~~text
        ### 围栏中的标题
        ~~~~
        """

        let headings = MarkdownDiffEngine.parseSections(content).map(\.heading)

        XCTAssertEqual(headings, ["# Markdown 语法", "## 正常标题"])
    }

    func testLocalAndGitDiffProduceSameContentChangeHash() {
        let oldContent = "# FreeRTOS\n队列用于任务通信。"
        let newContent = "# FreeRTOS\n队列用于任务通信。\n\n## 阻塞语义\n队列为空时接收任务可以阻塞等待。"
        let local = MarkdownDiffEngine.diff(oldContent: oldContent, newContent: newContent)
        let gitDiff = """
        diff --git a/note.md b/note.md
        --- a/note.md
        +++ b/note.md
        @@ -1,2 +1,5 @@
         # FreeRTOS
         队列用于任务通信。
        +
        +## 阻塞语义
        +队列为空时接收任务可以阻塞等待。
        """

        XCTAssertEqual(local.normalizedDiffHash, MarkdownDiffEngine.contentChangeHash(fromGitDiff: gitDiff))
    }

    // MARK: - 2. Markdown Snapshot 存储测试

    func testMarkdownSnapshotStore() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = MarkdownSnapshotStore(storageDirectoryURL: tempDir)
        let sourceID = UUID()
        let filePath = "/tmp/notes/linux.md"
        let snapshot = MarkdownSnapshot(
            sourceID: sourceID,
            filePath: filePath,
            contentHash: "hash123",
            content: "# Linux Notes",
            modifiedAt: .now
        )

        await store.saveSnapshot(snapshot)
        let loaded = await store.snapshot(sourceID: sourceID, filePath: filePath)
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.content, "# Linux Notes")
        XCTAssertEqual(loaded?.contentHash, "hash123")

        // 重命名
        let newFilePath = "/tmp/notes/linux_os.md"
        await store.renameSnapshot(sourceID: sourceID, from: filePath, to: newFilePath)
        let oldLoaded = await store.snapshot(sourceID: sourceID, filePath: filePath)
        let newLoaded = await store.snapshot(sourceID: sourceID, filePath: newFilePath)
        XCTAssertNil(oldLoaded)
        XCTAssertEqual(newLoaded?.content, "# Linux Notes")

        // 移除
        await store.removeSnapshot(sourceID: sourceID, filePath: newFilePath)
        let removed = await store.snapshot(sourceID: sourceID, filePath: newFilePath)
        XCTAssertNil(removed)
    }

    // MARK: - 3. Markdown 防抖合并引擎测试

    private final class ResultCollector: @unchecked Sendable {
        var files: [String] = []
        let lock = NSLock()

        func setFiles(_ newFiles: [String]) {
            lock.lock()
            defer { lock.unlock() }
            files = newFiles
        }

        func getFiles() -> [String] {
            lock.lock()
            defer { lock.unlock() }
            return files
        }
    }

    func testMarkdownEventDebouncer() async throws {
        let debouncer = MarkdownEventDebouncer(debounceDuration: .milliseconds(300))
        let sourceID = UUID()
        let collector = ResultCollector()
        let expectation = expectation(description: "Debounced flush")

        await debouncer.enqueue(sourceID: sourceID, paths: ["/path/a.md"]) { _, paths in
            collector.setFiles(paths)
            expectation.fulfill()
        }

        // 在 100ms 内再次推送 /path/a.md 和 /path/b.md（防抖合并）
        try await Task.sleep(for: .milliseconds(100))
        await debouncer.enqueue(sourceID: sourceID, paths: ["/path/b.md"]) { _, paths in
            collector.setFiles(paths)
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 2.0)
        let flushed = collector.getFiles()
        XCTAssertEqual(flushed.count, 2)
        XCTAssertTrue(flushed.contains("/path/a.md"))
        XCTAssertTrue(flushed.contains("/path/b.md"))
    }

    // MARK: - 4. Markdown Connector 增量处理与删除测试

    func testMarkdownConnectorIncrementalDiff() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let snapshotStore = MarkdownSnapshotStore(storageDirectoryURL: tempDir.appendingPathComponent("snapshots"))
        let connector = MarkdownActivityConnector(snapshotStore: snapshotStore)
        let sourceID = UUID()
        let source = SourceDescriptor(
            id: sourceID,
            name: "Test Notes",
            kind: .markdownDirectory,
            path: tempDir.path
        )

        let noteURL = tempDir.appendingPathComponent("freertos.md")
        try "# FreeRTOS\n初次创建笔记内容。".write(to: noteURL, atomically: true, encoding: .utf8)

        // 第一次扫描：全新文件产生 1 条 Activity
        let firstBatch = await connector.processChangedFiles(source: source, filePaths: [noteURL.path])
        XCTAssertEqual(firstBatch.activities.count, 1)
        XCTAssertEqual(firstBatch.activities.first?.title, "FreeRTOS")
        await connector.commitSnapshotMutations(firstBatch.markdownSnapshotMutations)

        // 未修改内容时再次处理：产生 0 条 Activity
        let secondBatch = await connector.processChangedFiles(source: source, filePaths: [noteURL.path])
        XCTAssertEqual(secondBatch.activities.count, 0)

        // 修改内容后处理：产生 1 条增量 Diff Activity
        try "# FreeRTOS\n初次创建笔记内容。\n\n## 队列通信\n使用 xQueueSend 与 xQueueReceive 实现任务间通信。".write(to: noteURL, atomically: true, encoding: .utf8)
        let thirdBatch = await connector.processChangedFiles(source: source, filePaths: [noteURL.path])
        XCTAssertEqual(thirdBatch.activities.count, 1)
        XCTAssertTrue(thirdBatch.activities.first?.excerpt.contains("队列通信") == true)
        await connector.commitSnapshotMutations(thirdBatch.markdownSnapshotMutations)

        // 同一文件再次修改必须产生第二条具有独立 eventFingerprint 的真实增量。
        try "# FreeRTOS\n初次创建笔记内容。\n\n## 队列通信\n使用 xQueueSend 与 xQueueReceive 实现任务间通信。\n队列满时发送任务可以阻塞等待。".write(to: noteURL, atomically: true, encoding: .utf8)
        let fourthBatch = await connector.processChangedFiles(source: source, filePaths: [noteURL.path])
        XCTAssertEqual(fourthBatch.activities.count, 1)
        XCTAssertNotEqual(thirdBatch.activities.first?.fingerprint, fourthBatch.activities.first?.fingerprint)
        await connector.commitSnapshotMutations(fourthBatch.markdownSnapshotMutations)

        // 删除文件：产生 0 条 Activity，快照清理
        try FileManager.default.removeItem(at: noteURL)
        let deletionBatch = await connector.processChangedFiles(source: source, filePaths: [noteURL.path])
        XCTAssertEqual(deletionBatch.activities.count, 0)
        await connector.commitSnapshotMutations(deletionBatch.markdownSnapshotMutations)
        let snapshot = await snapshotStore.snapshot(sourceID: sourceID, filePath: noteURL.path)
        XCTAssertNil(snapshot)
    }

    func testMarkdownConnectorTitleExtractionIgnoresCodeAndPreprocessor() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let snapshotStore = MarkdownSnapshotStore(storageDirectoryURL: tempDir.appendingPathComponent("snapshots"))
        let connector = MarkdownActivityConnector(snapshotStore: snapshotStore)
        let source = SourceDescriptor(name: "Test", kind: .markdownDirectory, path: tempDir.path)

        // 包含首行代码块及 #include 的 Markdown
        let noteURL = tempDir.appendingPathComponent("c_programming.md")
        let content = """
        ```c
        #include <stdio.h>
        #include <stdlib.h>
        # 这不是标题
        ```

        # C 语言内存管理
        malloc 与 free 的用法。
        """
        try content.write(to: noteURL, atomically: true, encoding: .utf8)

        let batch = await connector.processChangedFiles(source: source, filePaths: [noteURL.path])
        XCTAssertEqual(batch.activities.count, 1)
        XCTAssertEqual(batch.activities.first?.title, "C 语言内存管理", "应提取首个合规的 ATX Heading，忽略代码块与预处理指令")
    }

    func testUncommittedActivityDoesNotAdvanceSnapshot() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let snapshotStore = MarkdownSnapshotStore(storageDirectoryURL: tempDir.appendingPathComponent("snapshots"))
        let connector = MarkdownActivityConnector(snapshotStore: snapshotStore)
        let source = SourceDescriptor(name: "Test", kind: .markdownDirectory, path: tempDir.path)
        let noteURL = tempDir.appendingPathComponent("linux.md")
        try "# Linux\nfork 创建子进程。".write(to: noteURL, atomically: true, encoding: .utf8)

        let failedPersistenceAttempt = await connector.processChangedFiles(source: source, filePaths: [noteURL.path])
        XCTAssertEqual(failedPersistenceAttempt.activities.count, 1)
        let snapshotAfterFailure = await snapshotStore.snapshot(sourceID: source.id, filePath: noteURL.path)
        XCTAssertNil(snapshotAfterFailure)

        let retry = await connector.processChangedFiles(source: source, filePaths: [noteURL.path])
        XCTAssertEqual(retry.activities.first?.fingerprint, failedPersistenceAttempt.activities.first?.fingerprint)
        XCTAssertEqual(retry.activities.count, 1, "Activity 保存失败后同一变化必须仍可重试采集")
    }

    func testRenameWithIdenticalContentMovesSnapshotWithoutActivity() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let snapshotStore = MarkdownSnapshotStore(storageDirectoryURL: tempDir.appendingPathComponent("snapshots"))
        let connector = MarkdownActivityConnector(snapshotStore: snapshotStore)
        let source = SourceDescriptor(name: "Test", kind: .markdownDirectory, path: tempDir.path)
        let oldURL = tempDir.appendingPathComponent("old.md")
        let newURL = tempDir.appendingPathComponent("moved.md")
        try "# Linux 进程\nfork 创建子进程。".write(to: oldURL, atomically: true, encoding: .utf8)

        let initial = await connector.processChangedFiles(source: source, filePaths: [oldURL.path])
        await connector.commitSnapshotMutations(initial.markdownSnapshotMutations)
        try FileManager.default.moveItem(at: oldURL, to: newURL)

        let rename = await connector.processChangedFiles(source: source, filePaths: [oldURL.path, newURL.path])
        XCTAssertTrue(rename.activities.isEmpty)
        await connector.commitSnapshotMutations(rename.markdownSnapshotMutations)
        let oldSnapshot = await snapshotStore.snapshot(sourceID: source.id, filePath: oldURL.path)
        let newSnapshot = await snapshotStore.snapshot(sourceID: source.id, filePath: newURL.path)
        XCTAssertNil(oldSnapshot)
        XCTAssertNotNil(newSnapshot)
    }

    // MARK: - 5. 防双重计分测试 (Local vs Remote Git 相同指纹)

    @MainActor
    func testAntiDoubleScoringForDuplicateProvenance() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Schema(versionedSchema: AscendSchemaV7.self), configurations: [config])
        let appState = AppState(modelContainer: container)

        // 创建知识点
        let node = KnowledgeNode(name: "FreeRTOS 队列", domain: "嵌入式系统")
        container.mainContext.insert(node)
        try container.mainContext.save()
        appState.reload()

        let normalizedHash = MarkdownDiffEngine.hexDigest("freertos 队列任务间通信")
        let timestamp1 = Date(timeIntervalSince1970: 1_000_000)
        let timestamp2 = Date(timeIntervalSince1970: 1_000_500)

        // 模拟本地 FSEvents 产生的证据与审查建议
        let localActivityID = UUID()
        container.mainContext.insert(ActivityEvent(
            id: localActivityID,
            sourceID: UUID(),
            sourceKind: .markdownDirectory,
            timestamp: timestamp1,
            fingerprint: "local-event",
            contentChangeHash: normalizedHash,
            title: "本地队列笔记",
            sourceLocator: "/notes/queue.md",
            summary: "本地 Markdown",
            excerpt: "队列任务间通信"
        ))
        let localEvidence = EvidenceRecord(
            activityID: localActivityID,
            knowledgeNodeID: node.id,
            kind: .explanation,
            timestamp: timestamp1,
            summary: "本地 Markdown 记录队列通信",
            rationale: "自主整理",
            difficulty: 1.0,
            independence: 1.0,
            aiConfidence: 0.9,
            isVerified: false,
            fingerprint: "local-event-\(node.id.uuidString)",
            contentChangeHash: normalizedHash
        )
        container.mainContext.insert(localEvidence)
        let suggestion1 = TaxonomySuggestion(
            suggestionType: "reviewEvidence",
            proposedName: node.name,
            relatedNodeID: node.id,
            activityID: localActivityID,
            evidenceID: localEvidence.id,
            rationale: "本地记录",
            confidence: 0.9
        )
        container.mainContext.insert(suggestion1)
        try container.mainContext.save()
        appState.reload()

        // 批准证据沉淀，推动自然成长并获得初始 XP
        appState.approveSuggestion(suggestion1)
        let initialXP = appState.totalXP
        XCTAssertGreaterThan(initialXP, 0)

        // 模拟后续远端 Git Commit 产生的证据（相同语义内容与指纹）
        let remoteActivityID = UUID()
        container.mainContext.insert(ActivityEvent(
            id: remoteActivityID,
            sourceID: UUID(),
            sourceKind: .remoteGitMarkdown,
            timestamp: timestamp2,
            fingerprint: "remote-event",
            contentChangeHash: normalizedHash,
            title: "远端队列笔记",
            sourceLocator: "/repo#commit:queue.md",
            summary: "Remote Git Markdown",
            excerpt: "队列任务间通信"
        ))
        let remoteEvidence = EvidenceRecord(
            activityID: remoteActivityID,
            knowledgeNodeID: node.id,
            kind: .explanation,
            timestamp: timestamp2,
            summary: "远程 Git push 提交队列通信",
            rationale: "代码提交",
            difficulty: 1.0,
            independence: 1.0,
            aiConfidence: 0.9,
            isVerified: false,
            fingerprint: "remote-event-\(node.id.uuidString)",
            contentChangeHash: normalizedHash
        )
        container.mainContext.insert(remoteEvidence)
        let suggestion2 = TaxonomySuggestion(
            suggestionType: "reviewEvidence",
            proposedName: node.name,
            relatedNodeID: node.id,
            activityID: remoteActivityID,
            evidenceID: remoteEvidence.id,
            rationale: "远程提交",
            confidence: 0.9
        )
        container.mainContext.insert(suggestion2)
        try container.mainContext.save()
        appState.reload()

        // 批准重复证据 -> 记录通过，但 XP 不再重复增加
        appState.approveSuggestion(suggestion2)
        let xpAfterDuplicate = appState.totalXP
        XCTAssertEqual(initialXP, xpAfterDuplicate, "相同内容哈希的远程 Git 提交不应造成重复计分")
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<ActivityEvent>()), 2, "两条来源 provenance 应同时保留")
    }

    // MARK: - 6. 历史重复待分析活动自愈清理测试

    @MainActor
    func testCleanupDuplicateActivityEvents() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Schema(versionedSchema: AscendSchemaV7.self), configurations: [config])

        let sourceID = UUID()
        let locator = "/path/notes/06-process.md"
        let timestamp = Date(timeIntervalSince1970: 1_000_000)

        // 插入旧的已处理活动
        let processedEvent = ActivityEvent(
            sourceID: sourceID,
            sourceKind: .markdownDirectory,
            timestamp: timestamp,
            fingerprint: "old-hash-1",
            title: "06 进程",
            sourceLocator: locator,
            summary: "Markdown 更新 · 06-进程.md",
            excerpt: "旧内容",
            isProcessed: true
        )
        container.mainContext.insert(processedEvent)

        // 同一路径的后续真实修改拥有不同指纹，必须保留。
        let laterEvent = ActivityEvent(
            sourceID: sourceID,
            sourceKind: .markdownDirectory,
            timestamp: timestamp,
            fingerprint: "new-hash-2",
            title: "06 进程",
            sourceLocator: locator,
            summary: "Markdown 增量 · 06-进程.md",
            excerpt: "新增量",
            isProcessed: false
        )
        container.mainContext.insert(laterEvent)
        try container.mainContext.save()

        // 初始化 AppState 时会自动触发清理
        let appState = AppState(modelContainer: container)
        appState.reload()

        let remainingEvents = try container.mainContext.fetch(FetchDescriptor<ActivityEvent>())
        XCTAssertEqual(remainingEvents.count, 2)
        XCTAssertEqual(Set(remainingEvents.map(\.fingerprint)), ["old-hash-1", "new-hash-2"])
    }
}
