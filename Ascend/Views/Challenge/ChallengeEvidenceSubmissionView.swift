import CryptoKit
import SwiftUI
import UniformTypeIdentifiers

/// 用户主动把真实提交交给 AI 核验；只发送有限审计片段，不做作者身份判断。
struct ChallengeEvidenceSubmissionView: View {
    private enum SourceMode: String, CaseIterable, Identifiable {
        case collectedGit = "已采集 Git 提交"
        case localFile = "本地文件"

        var id: Self { self }
    }

    private struct LocalFileReference {
        let title: String
        let locator: String
        let hash: String
        let modifiedAt: Date
        let auditExcerpt: String
    }

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let challenge: Challenge

    @State private var sourceMode: SourceMode = .collectedGit
    @State private var selectedActivityID: UUID?
    @State private var selectedFile: LocalFileReference?
    @State private var selectedNodeIDs: Set<UUID> = []
    @State private var detail = ""
    @State private var declaresIndependent = false
    @State private var confirmsRealProject = false
    @State private var confirmsCoreWork = false
    @State private var confirmsQuality = false
    @State private var showsFileImporter = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var reviewMessage: String?
    @State private var submissionTask: Task<Void, Never>?

    private var targetNodes: [KnowledgeNode] {
        challenge.knowledgeNodeIDs.compactMap(appState.node(for:))
    }

    private var gitActivities: [ActivityEvent] {
        return appState.activityEvents
            .filter {
                $0.timestamp >= Date.now.addingTimeInterval(-3 * 86_400) &&
                [
                    SourceKind.gitRepository,
                    .remoteGitRepository,
                    .remoteGitMarkdown
                ].contains($0.sourceKind)
            }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private var selectedGitActivity: ActivityEvent? {
        guard let selectedActivityID else { return nil }
        return gitActivities.first(where: { $0.id == selectedActivityID })
    }

    private var selectedSource: SubmittedPerformanceEvidence? {
        switch sourceMode {
        case .collectedGit:
            guard let activity = selectedGitActivity else { return nil }
            return SubmittedPerformanceEvidence(
                title: activity.title,
                sourceLocator: activity.sourceLocator,
                contentChangeHash: activity.contentChangeHash ?? stableHash(activity.sourceLocator + activity.fingerprint),
                sourceKind: activity.sourceKind,
                occurredAt: activity.timestamp,
                auditExcerpt: String(activity.excerpt.prefix(AppConstants.maximumLLMExcerptLength))
            )
        case .localFile:
            guard let selectedFile else { return nil }
            return SubmittedPerformanceEvidence(
                title: selectedFile.title,
                sourceLocator: selectedFile.locator,
                contentChangeHash: selectedFile.hash,
                sourceKind: .manual,
                occurredAt: selectedFile.modifiedAt,
                auditExcerpt: selectedFile.auditExcerpt
            )
        }
    }

    private var sourceIsRecent: Bool {
        guard let source = selectedSource else { return false }
        return source.occurredAt >= Date.now.addingTimeInterval(-3 * 86_400)
    }

    private var canSubmit: Bool {
        selectedSource != nil &&
            sourceIsRecent &&
            !selectedNodeIDs.isEmpty &&
            declaresIndependent &&
            confirmsRealProject &&
            confirmsCoreWork &&
            confirmsQuality &&
            !isSubmitting
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(
                "提交挑战实作证据",
                subtitle: "仅向已配置 AI 接口发送必要的审计片段以核验挑战；不上传完整源码，也不判断作者身份。",
                systemImage: "tray.and.arrow.up"
            ) { EmptyView() }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    sourceSection
                    targetSection
                    declarationSection

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(AscendTheme.cinnabar)
                    }
                    if let reviewMessage {
                        Label(reviewMessage, systemImage: "text.append")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("取消", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if isSubmitting {
                    Button("取消核验", role: .cancel) {
                        submissionTask?.cancel()
                        submissionTask = nil
                        isSubmitting = false
                        errorMessage = "已取消本次 AI 核验；尚未写入任何挑战结果。"
                    }
                    .controlSize(.small)
                }
                Button(isSubmitting ? "正在核验…" : "提交并核验", systemImage: "checkmark.seal") {
                    submissionTask = Task { await submit() }
                }
                    .buttonStyle(.borderedProminent)
                    .tint(AscendTheme.gold)
                    .disabled(!canSubmit)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 610, height: 620)
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false,
            onCompletion: importFile
        )
        .onAppear {
            if selectedNodeIDs.isEmpty {
                selectedNodeIDs = Set(targetNodes.map(\.id))
            }
            if selectedActivityID == nil {
                selectedActivityID = gitActivities.first?.id
            }
        }
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("实作来源", systemImage: "link")

            Picker("来源类型", selection: $sourceMode) {
                ForEach(SourceMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch sourceMode {
            case .collectedGit:
                if gitActivities.isEmpty {
                    ContentUnavailableView(
                        "暂无已采集 Git 提交",
                        systemImage: "arrow.triangle.branch",
                        description: Text("请先巡察/同步远端仓库；这里只显示最近三天的提交。")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                } else {
                    Picker("已采集提交", selection: $selectedActivityID) {
                        ForEach(gitActivities.prefix(50)) { activity in
                            Text(gitActivityLabel(activity))
                                .tag(Optional(activity.id))
                        }
                    }
                    Text(selectedGitActivity.map(gitActivityDetail) ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            case .localFile:
                HStack(spacing: 10) {
                    Button(selectedFile == nil ? "选择本地文件" : "更换本地文件", systemImage: "doc.badge.plus") {
                        showsFileImporter = true
                    }
                    if let selectedFile {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedFile.title)
                            Text("修改于 \(selectedFile.modifiedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if selectedSource != nil && !sourceIsRecent {
                Label("所选来源超过三天，不能作为本挑战的完成证据。", systemImage: "clock.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(AscendTheme.cinnabar)
            }

            Text("Git 记录复用资料流的定位、哈希与受限审计片段；本地文件仅在本机读取后提取有限片段。验证仅接受最近三天的来源；完整源码不会保存或发送。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var targetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("覆盖的挑战知窍", systemImage: "point.3.filled.connected.trianglepath.dotted")
            Text("每一处知窍都需要接取后的直接实据；一份真实实作可在确实覆盖时选择多处。")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(targetNodes) { node in
                Toggle(node.name, isOn: nodeBinding(node.id))
                    .toggleStyle(.checkbox)
            }
        }
    }

    private var declarationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("独立实作声明", systemImage: "checkmark.shield")
            Toggle("本次实作未借助资料、提示或 AI，由我独立完成", isOn: $declaresIndependent)
            Toggle("实作发生在真实项目或工作情境中，而非照抄教程", isOn: $confirmsRealProject)
            Toggle("我独立解决了这项挑战涉及的核心问题", isOn: $confirmsCoreWork)
            Toggle("实作结果达到我或团队预期的质量要求", isOn: $confirmsQuality)

            TextField("补充说明（可选）：做了什么、测试或运行结果", text: $detail, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
        }
    }

    private func nodeBinding(_ nodeID: UUID) -> Binding<Bool> {
        Binding(
            get: { selectedNodeIDs.contains(nodeID) },
            set: { selected in
                if selected {
                    selectedNodeIDs.insert(nodeID)
                } else {
                    selectedNodeIDs.remove(nodeID)
                }
            }
        )
    }

    private func gitActivityLabel(_ activity: ActivityEvent) -> String {
        let parts = gitLocatorParts(activity.sourceLocator)
        let fileLabel: String
        if parts.path == "code" {
            fileLabel = activity.summary.replacingOccurrences(of: "[代码实践] ", with: "代码：")
        } else if parts.path.isEmpty {
            fileLabel = activity.title
        } else {
            fileLabel = parts.path
        }
        return "\(fileLabel) · \(parts.commitShort) · \(activity.timestamp.formatted(date: .abbreviated, time: .shortened))"
    }

    private func gitActivityDetail(_ activity: ActivityEvent) -> String {
        let parts = gitLocatorParts(activity.sourceLocator)
        guard !parts.path.isEmpty else { return activity.sourceLocator }
        return "\(parts.path) · commit \(parts.commitShort) · \(activity.title)"
    }

    private func gitLocatorParts(_ locator: String) -> (commitShort: String, path: String) {
        guard let hashMarker = locator.lastIndex(of: "#") else {
            return ("未知提交", URL(fileURLWithPath: locator).lastPathComponent)
        }
        let suffix = locator[locator.index(after: hashMarker)...]
        guard let separator = suffix.firstIndex(of: ":") else {
            return (String(suffix.prefix(7)), "")
        }
        let commit = String(suffix[..<separator])
        let path = String(suffix[suffix.index(after: separator)...])
        return (String(commit.prefix(7)), path)
    }

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.callout)
            .bold()
    }

    private func importFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let gainedAccess = url.startAccessingSecurityScopedResource()
            defer {
                if gainedAccess { url.stopAccessingSecurityScopedResource() }
            }
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey])
            guard values.isRegularFile == true else {
                errorMessage = "请选择单个文件，而不是目录。"
                return
            }
            guard (values.fileSize ?? 0) <= 25 * 1_024 * 1_024 else {
                errorMessage = "文件超过 25 MB；请提交对应 Git 记录或更小的可核验文件。"
                return
            }
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            selectedFile = LocalFileReference(
                title: url.lastPathComponent,
                locator: url.path,
                hash: stableHash(data),
                modifiedAt: values.contentModificationDate ?? .now,
                auditExcerpt: String(
                    data: data.prefix(AppConstants.maximumLLMExcerptLength),
                    encoding: .utf8
                ) ?? "该文件不是可直接读取的文本；请在补充说明中提供可核验的测试或变更信息。"
            )
            errorMessage = nil
        } catch {
            errorMessage = "读取本地文件失败：\(error.localizedDescription)"
        }
    }

    private func submit() async {
        guard let source = selectedSource, canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        reviewMessage = nil
        defer { isSubmitting = false }
        do {
            try Task.checkCancellation()
            let review = try await appState.reviewAndSubmitChallengePerformanceEvidence(
                for: challenge,
                source: source,
                nodeIDs: selectedNodeIDs,
                detail: detail
            )
            if ChallengeEvidenceReviewPolicy.isPassing(review) {
                dismiss()
            } else {
                reviewMessage = "本次未通过：\(review.failureReasons.joined(separator: "；"))。下次提交会自动带上这些缺口供 AI 对照。"
            }
        } catch {
            errorMessage = error is CancellationError
                ? "已取消本次 AI 核验；尚未写入任何挑战结果。"
                : error.localizedDescription
        }
    }

    private func stableHash(_ value: String) -> String {
        stableHash(Data(value.utf8))
    }

    private func stableHash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
