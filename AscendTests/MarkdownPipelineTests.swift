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
        XCTAssertEqual(firstBatch.count, 1)
        XCTAssertEqual(firstBatch.first?.title, "FreeRTOS")

        // 未修改内容时再次处理：产生 0 条 Activity
        let secondBatch = await connector.processChangedFiles(source: source, filePaths: [noteURL.path])
        XCTAssertEqual(secondBatch.count, 0)

        // 修改内容后处理：产生 1 条增量 Diff Activity
        try "# FreeRTOS\n初次创建笔记内容。\n\n## 队列通信\n使用 xQueueSend 与 xQueueReceive 实现任务间通信。".write(to: noteURL, atomically: true, encoding: .utf8)
        let thirdBatch = await connector.processChangedFiles(source: source, filePaths: [noteURL.path])
        XCTAssertEqual(thirdBatch.count, 1)
        XCTAssertTrue(thirdBatch.first?.excerpt.contains("队列通信") == true)

        // 删除文件：产生 0 条 Activity，快照清理
        try FileManager.default.removeItem(at: noteURL)
        let fourthBatch = await connector.processChangedFiles(source: source, filePaths: [noteURL.path])
        XCTAssertEqual(fourthBatch.count, 0)
        let snapshot = await snapshotStore.snapshot(sourceID: sourceID, filePath: noteURL.path)
        XCTAssertNil(snapshot)
    }

    // MARK: - 5. 防双重计分测试 (Local vs Remote Git 相同指纹)

    @MainActor
    func testAntiDoubleScoringForDuplicateProvenance() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Schema(versionedSchema: AscendSchemaV5.self), configurations: [config])
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
            fingerprint: "\(normalizedHash)-\(node.id.uuidString)"
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

        // 批准首次证据 -> 获得 XP
        appState.approveSuggestion(suggestion1)
        let initialXP = appState.totalXP
        XCTAssertGreaterThan(initialXP, 0, "首次已验证证据应获取 XP")

        // 模拟后续远端 Git Commit 产生的证据（相同语义内容与指纹）
        let remoteActivityID = UUID()
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
            fingerprint: "\(normalizedHash)-\(node.id.uuidString)"
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
    }

    // MARK: - 6. 历史重复待分析活动自愈清理测试

    @MainActor
    func testCleanupDuplicateActivityEvents() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Schema(versionedSchema: AscendSchemaV5.self), configurations: [config])

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

        // 插入重复产生的待分析活动
        let pendingDuplicateEvent = ActivityEvent(
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
        container.mainContext.insert(pendingDuplicateEvent)
        try container.mainContext.save()

        // 初始化 AppState 时会自动触发清理
        let appState = AppState(modelContainer: container)
        appState.reload()

        let remainingEvents = try container.mainContext.fetch(FetchDescriptor<ActivityEvent>())
        XCTAssertEqual(remainingEvents.count, 1)
        XCTAssertTrue(remainingEvents.first?.isProcessed == true)
        XCTAssertEqual(remainingEvents.first?.title, "06 进程")
    }
}
