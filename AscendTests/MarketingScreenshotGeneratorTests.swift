import AppKit
import SwiftData
import SwiftUI
import XCTest
@testable import Ascend

final class MarketingScreenshotGeneratorTests: XCTestCase {

    @MainActor
    func testGenerateMarketingScreenshots() throws {
        let schema = Schema(AscendSchemaV7.models)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let appState = AppState(modelContainer: container)

        // 1. 构造精美且真实的「Linux 系统编程」与「Swift 并发」领域数据
        let nodeFork = KnowledgeNode(name: "进程模型与 fork", domain: "系统编程")
        let nodeWaitpid = KnowledgeNode(name: "进程回收与 waitpid", domain: "系统编程")
        let nodeIPC = KnowledgeNode(name: "进程间管道通信 (IPC)", domain: "系统编程")
        let nodeEpoll = KnowledgeNode(name: "I/O 多路复用 epoll", domain: "系统编程")
        let nodeActor = KnowledgeNode(name: "Actor 隔离模型", domain: "Swift 并发")
        let nodeTask = KnowledgeNode(name: "Structured Concurrency", domain: "Swift 并发")

        container.mainContext.insert(nodeFork)
        container.mainContext.insert(nodeWaitpid)
        container.mainContext.insert(nodeIPC)
        container.mainContext.insert(nodeEpoll)
        container.mainContext.insert(nodeActor)
        container.mainContext.insert(nodeTask)

        // 2. 建立先导与关联灵脉 (KnowledgeEdge)
        let edge1 = KnowledgeEdge(sourceNodeID: nodeFork.id, targetNodeID: nodeWaitpid.id, relation: .prerequisite, confidence: 0.95, rationale: "fork 子进程的生命周期管理与状态回收依赖 waitpid", origin: "userConfirmed", createdAt: Date(), confirmedAt: Date())
        let edge2 = KnowledgeEdge(sourceNodeID: nodeFork.id, targetNodeID: nodeIPC.id, relation: .prerequisite, confidence: 0.92, rationale: "管道与共享内存建立在父子进程上下文之上", origin: "userConfirmed", createdAt: Date(), confirmedAt: Date())
        let edge3 = KnowledgeEdge(sourceNodeID: nodeIPC.id, targetNodeID: nodeEpoll.id, relation: .applies, confidence: 0.88, rationale: "通过 epoll 统一监听多个 IPC 描述符", origin: "ai", createdAt: Date())
        let edge4 = KnowledgeEdge(sourceNodeID: nodeTask.id, targetNodeID: nodeActor.id, relation: .prerequisite, confidence: 0.96, rationale: "任务生命周期是 Actor 跨隔离边界调用的基础", origin: "userConfirmed", createdAt: Date(), confirmedAt: Date())

        container.mainContext.insert(edge1)
        container.mainContext.insert(edge2)
        container.mainContext.insert(edge3)
        container.mainContext.insert(edge4)

        // 3. 注入五维认知心印与修真境界 (MasteryState)
        let masteryFork = MasteryState(
            knowledgeNodeID: nodeFork.id,
            vector: MasteryVector(exposure: 85, understanding: 80, practice: 75, retention: 70, autonomy: 75),
            confidence: 92,
            stabilityDays: 14,
            lastEvidenceAt: Date(),
            lifetimeXP: 450,
            highestStage: .integrated
        )
        let masteryWaitpid = MasteryState(
            knowledgeNodeID: nodeWaitpid.id,
            vector: MasteryVector(exposure: 75, understanding: 70, practice: 65, retention: 60, autonomy: 60),
            confidence: 88,
            stabilityDays: 10,
            lastEvidenceAt: Date(),
            lifetimeXP: 320,
            highestStage: .proficient
        )
        let masteryIPC = MasteryState(
            knowledgeNodeID: nodeIPC.id,
            vector: MasteryVector(exposure: 60, understanding: 55, practice: 50, retention: 45, autonomy: 40),
            confidence: 80,
            stabilityDays: 7,
            lastEvidenceAt: Date(),
            lifetimeXP: 210,
            highestStage: .proficient
        )
        let masteryEpoll = MasteryState(
            knowledgeNodeID: nodeEpoll.id,
            vector: MasteryVector(exposure: 30, understanding: 20, practice: 0, retention: 20, autonomy: 10),
            confidence: 65,
            stabilityDays: 3,
            lastEvidenceAt: Date(),
            lifetimeXP: 60,
            highestStage: .entry
        )

        container.mainContext.insert(masteryFork)
        container.mainContext.insert(masteryWaitpid)
        container.mainContext.insert(masteryIPC)
        container.mainContext.insert(masteryEpoll)

        // 4. 注入 FSRS 记忆状态 (MemoryState)
        let now = Date()
        let memFork = MemoryState(knowledgeNodeID: nodeFork.id, difficulty: 3.5, stability: 12.0, retrievability: 0.88, lastReviewAt: now.addingTimeInterval(-86400 * 2), nextReviewAt: now.addingTimeInterval(86400 * 10), reps: 4, lapses: 0)
        let memIPC = MemoryState(knowledgeNodeID: nodeIPC.id, difficulty: 4.2, stability: 4.0, retrievability: 0.55, lastReviewAt: now.addingTimeInterval(-86400 * 4), nextReviewAt: now.addingTimeInterval(-3600), reps: 2, lapses: 1)
        container.mainContext.insert(memFork)
        container.mainContext.insert(memIPC)

        // 5. 注入真实实据 (EvidenceRecord)
        let ev1 = EvidenceRecord(
            activityID: UUID(),
            knowledgeNodeID: nodeFork.id,
            kind: .exercise,
            timestamp: now.addingTimeInterval(-3600 * 3),
            summary: "实现了守护进程双重 fork 与进程会话脱离",
            rationale: "在 daemonize() 函数中完成 setsid 和重定向",
            difficulty: 3.8,
            independence: 0.9,
            aiConfidence: 0.94,
            isVerified: true,
            fingerprint: "git-commit-fork-demo"
        )
        let ev2 = EvidenceRecord(
            activityID: UUID(),
            knowledgeNodeID: nodeIPC.id,
            kind: .exposure,
            timestamp: now.addingTimeInterval(-3600 * 6),
            summary: "研读 POSIX 匿名管道与命名管道 FIFO 缓冲区行为",
            rationale: "深入理解 O_NONBLOCK 下的 read/write 阻塞语义",
            difficulty: 3.2,
            independence: 0.7,
            aiConfidence: 0.89,
            isVerified: true,
            fingerprint: "markdown-ipc-notes"
        )
        container.mainContext.insert(ev1)
        container.mainContext.insert(ev2)

        // 6. 注入今日知得 (DailyDigest)
        let digest = DailyDigest(
            date: now,
            summary: "今日聚焦 Unix 系统进程生命周期与管道通信，完成了双重 fork 守护进程实践与 FIFO 边界条件探究，主修道行突破至融会贯通境界。",
            xpEarned: 180
        )
        container.mainContext.insert(digest)

        try container.mainContext.save()
        appState.reload()

        let assetsDir = URL(fileURLWithPath: "/Users/yang/Desktop/projet/Ascend/assets")
        try? FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)

        // A. 渲染「天球星宿图谱与先导灵脉」
        let constellationView = CelestialConstellationGraphView(
            domainName: "系统编程",
            nodes: [nodeFork, nodeWaitpid, nodeIPC, nodeEpoll],
            selectedNodeID: nodeFork.id,
            score: { appState.currentComposite(for: $0.id) },
            onSelectNode: { _ in }
        )
        .environment(appState)
        .environment(\.colorScheme, .dark)
        .frame(width: 960, height: 600)

        renderViewToPNG(constellationView, size: CGSize(width: 960, height: 600), targetURL: assetsDir.appendingPathComponent("screenshot_constellation.png"))

        // B. 渲染「东方水墨研习长卷」
        let scrollView = CelestialStudyScrollView(isDark: true, date: now)
            .environment(appState)
            .frame(width: 680, height: 1100)

        renderViewToPNG(scrollView, size: CGSize(width: 680, height: 1100), targetURL: assetsDir.appendingPathComponent("screenshot_scroll.png"))

        // C. 渲染「菜单栏悟道驾舱」
        let menuBarView = MenuBarContentView()
            .environment(appState)
            .environment(\.colorScheme, .dark)
            .frame(width: 384, height: 520)

        renderViewToPNG(menuBarView, size: CGSize(width: 384, height: 520), targetURL: assetsDir.appendingPathComponent("screenshot_menubar.png"))

        // D. 渲染「修真大盘与五维心印」
        let dashboardView = TodayDashboardView()
            .environment(appState)
            .environment(\.colorScheme, .dark)
            .frame(width: 1080, height: 720)

        renderViewToPNG(dashboardView, size: CGSize(width: 1080, height: 720), targetURL: assetsDir.appendingPathComponent("screenshot_dashboard.png"))

        XCTAssertTrue(FileManager.default.fileExists(atPath: assetsDir.appendingPathComponent("screenshot_constellation.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: assetsDir.appendingPathComponent("screenshot_scroll.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: assetsDir.appendingPathComponent("screenshot_menubar.png").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: assetsDir.appendingPathComponent("screenshot_dashboard.png").path))
    }

    @MainActor
    private func renderViewToPNG<V: View>(_ view: V, size: CGSize, targetURL: URL) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()

        guard let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else { return }
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }
        try? pngData.write(to: targetURL)
    }
}
