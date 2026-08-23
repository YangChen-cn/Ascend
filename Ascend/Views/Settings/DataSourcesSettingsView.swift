import SwiftUI
import UniformTypeIdentifiers

struct DataSourcesSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showImporter = false
    @State private var pendingKind = SourceKind.gitRepository
    @State private var showRemoteGitSheet = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("研习数据源")
                        .font(.title2)
                        .bold()
                    Text("知境录仅扫描你主动授权的本地目录或 Git 仓库。本地 Markdown 享有 FSEvents 毫秒级实时监听。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button(action: addGitRepository) {
                        Label("Git 代码仓库…", systemImage: "arrow.triangle.branch")
                    }
                    Button(action: addMarkdownDirectory) {
                        Label("本地 Markdown / 笔记目录…", systemImage: "doc.text")
                    }
                    Button(action: addRemoteGitRepository) {
                        Label("远程 Git 仓库…", systemImage: "icloud.and.arrow.down")
                    }
                } label: {
                    Label("添加数据源", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(AscendTheme.jade)
            }

            if appState.sources.filter({ $0.path != "demo://" }).isEmpty {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AscendTheme.jade.opacity(0.12))
                            .frame(width: 56, height: 56)
                        Image(systemName: "externaldrive.badge.plus")
                            .font(.title2)
                            .foregroundStyle(AscendTheme.jade)
                    }

                    VStack(spacing: 4) {
                        Text("尚未连接研习数据源")
                            .font(.headline)
                        Text("点击右上角添加本地 Git 仓库、本地 Markdown 笔记目录或远程 Git 仓库，系统将安全采集研习活动。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 380)
                    }

                    HStack(spacing: 12) {
                        Button("添加 Git 仓库", systemImage: "arrow.triangle.branch", action: addGitRepository)
                            .buttonStyle(.bordered)
                        Button("添加 Markdown 目录", systemImage: "doc.text", action: addMarkdownDirectory)
                            .buttonStyle(.bordered)
                        Button("添加远程 Git 仓库", systemImage: "icloud.and.arrow.down", action: addRemoteGitRepository)
                            .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 220)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.02))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
            } else {
                List {
                    ForEach(appState.sources.filter { $0.path != "demo://" }) { source in
                        SourceSettingsRow(source: source)
                    }
                    .onDelete(perform: deleteSources)
                }
                .listStyle(.inset)
                .clipShape(.rect(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }
            }

            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .padding(8)
                .background(Color.red.opacity(0.08))
                .clipShape(.rect(cornerRadius: 8))
            }
        }
        .padding(20)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
        .sheet(isPresented: $showRemoteGitSheet) {
            AddRemoteGitSourceSheet { name, path, remoteURL, analyzeMarkdown, analyzeCode in
                do {
                    try appState.addSource(
                        name: name,
                        kind: .remoteGitRepository,
                        path: path,
                        analyzeMarkdown: analyzeMarkdown,
                        analyzeCode: analyzeCode,
                        remoteURLString: remoteURL
                    )
                    errorMessage = nil
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func addGitRepository() {
        pendingKind = .gitRepository
        showImporter = true
    }

    private func addMarkdownDirectory() {
        pendingKind = .markdownDirectory
        showImporter = true
    }

    private func addRemoteGitRepository() {
        showRemoteGitSheet = true
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            try appState.addSource(name: url.lastPathComponent, kind: pendingKind, path: url.path)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteSources(at offsets: IndexSet) {
        let visible = appState.sources.filter { $0.path != "demo://" }
        for index in offsets {
            try? appState.deleteSource(visible[index])
        }
    }
}

// MARK: - 远程 Git 仓库添加面板

private struct AddRemoteGitSourceSheet: View {
    @Environment(\.dismiss) private var dismiss

    enum AddMode: String, CaseIterable, Identifiable {
        case clone = "克隆 GitHub / 远端仓库"
        case local = "选择已有本地镜像"

        var id: Self { self }
    }

    @State private var mode: AddMode = .clone
    @State private var remoteURL: String = ""
    @State private var name: String = ""
    @State private var localPath: String = ""
    @State private var showFolderPicker = false
    @State private var isCloning = false
    @State private var analyzeMarkdown = true
    @State private var analyzeCode = true
    @State private var errorMessage: String?

    let onConfirm: (String, String, String?, Bool, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题栏
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "icloud.and.arrow.down")
                        .foregroundStyle(AscendTheme.jade)
                        .font(.title3)
                    Text("添加远程 Git 仓库数据源")
                        .font(.headline)
                }
                Spacer()
                Button("取消", role: .cancel) { dismiss() }
            }

            // 原理解析与架构图
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(AscendTheme.cobalt)
                        .font(.caption)
                    Text("知境录如何同步远端学习仓库？")
                        .font(.caption.bold())
                }

                HStack(spacing: 8) {
                    flowStep(title: "Ubuntu VM", desc: "git push", icon: "desktopcomputer")
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    flowStep(title: "GitHub 仓库", desc: "远端存储", icon: "cloud.fill")
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    flowStep(title: "Mac 本地镜像", desc: "git fetch", icon: "folder.fill")
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    flowStep(title: "知境录", desc: "增量 Diff", icon: "flame.fill", isHighlight: true)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )

                Text("知境录只在 Mac 上维护本地镜像并执行 git fetch。Markdown Diff 用于判断学习理解，代码 Diff 用于判断真实实践，两者分别形成可追溯活动。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AscendTheme.cobalt.opacity(0.05))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(AscendTheme.cobalt.opacity(0.12), lineWidth: 0.8)
            }

            // 模式切换
            Picker("添加方式", selection: $mode) {
                ForEach(AddMode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)

            if mode == .clone {
                // MARK: - 模式 A：从 GitHub / 远程链接直接克隆
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Git 仓库 URL")
                            .font(.caption.bold())
                        TextField("例如：https://github.com/username/notes.git", text: $remoteURL)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: remoteURL) { _, newValue in
                                autoDeriveNameAndPath(from: newValue)
                            }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("来源名称")
                            .font(.caption.bold())
                        TextField("例如：Ubuntu VM 研习笔记", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mac 本地镜像保存位置")
                            .font(.caption.bold())
                        HStack {
                            TextField("自动生成默认存放路径", text: $localPath)
                                .textFieldStyle(.roundedBorder)
                            Button("更改…") { showFolderPicker = true }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            } else {
                // MARK: - 模式 B：选择已有本地 Git 文件夹
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("来源名称")
                            .font(.caption.bold())
                        TextField("例如：Ubuntu VM 研习笔记", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("本地 Git 仓库路径")
                            .font(.caption.bold())
                        HStack {
                            TextField("~/Documents/Notes/my-notes", text: $localPath)
                                .textFieldStyle(.roundedBorder)
                            Button("浏览…") { showFolderPicker = true }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("分析内容")
                    .font(.caption)
                    .bold()
                Toggle("Markdown 学习笔记", isOn: $analyzeMarkdown)
                Toggle("代码提交", isOn: $analyzeCode)
            }
            .font(.caption)

            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .padding(6)
                .background(Color.red.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Divider()

            // 底部按钮
            HStack {
                Spacer()
                if mode == .clone {
                    Button(action: cloneAndAddSource) {
                        HStack(spacing: 6) {
                            if isCloning {
                                ProgressView()
                                    .controlSize(.small)
                                Text("正在克隆仓库…")
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("克隆并连接数据源")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AscendTheme.jade)
                    .disabled(
                        remoteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            isCloning || (!analyzeMarkdown && !analyzeCode)
                    )
                } else {
                    Button("完成添加") {
                        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? URL(fileURLWithPath: localPath).lastPathComponent
                            : name.trimmingCharacters(in: .whitespacesAndNewlines)
                        onConfirm(
                            finalName,
                            localPath.trimmingCharacters(in: .whitespacesAndNewlines),
                            nil,
                            analyzeMarkdown,
                            analyzeCode
                        )
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AscendTheme.jade)
                    .disabled(
                        localPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                            (!analyzeMarkdown && !analyzeCode)
                    )
                }
            }
        }
        .padding(22)
        .frame(minWidth: 540)
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if let url = try? result.get().first {
                localPath = url.path
                if name.isEmpty {
                    name = url.lastPathComponent
                }
            }
        }
    }

    private func flowStep(title: String, desc: String, icon: String, isHighlight: Bool = false) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(isHighlight ? AscendTheme.gold : .primary)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
            Text(desc)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func autoDeriveNameAndPath(from urlStr: String) {
        let trimmed = urlStr.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 提取 repo 名称 (例如 https://github.com/user/my-notes.git -> my-notes)
        let lastPart = trimmed.split(separator: "/").last ?? ""
        var repoName = String(lastPart)
        if repoName.hasSuffix(".git") {
            repoName = String(repoName.dropLast(4))
        }

        if !repoName.isEmpty {
            if name.isEmpty {
                name = repoName
            }
            let defaultBaseDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("Ascend/RemoteGitRepos", isDirectory: true)
            if let targetURL = defaultBaseDir?.appendingPathComponent(repoName, isDirectory: true) {
                localPath = targetURL.path
            }
        }
    }

    private func cloneAndAddSource() {
        let trimmedURL = remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPath = localPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty, !trimmedPath.isEmpty else { return }

        isCloning = true
        errorMessage = nil

        Task {
            do {
                let targetURL = URL(fileURLWithPath: trimmedPath)
                let parentDir = targetURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

                // 若目录已存在且为 git 仓库，直接使用；否则执行 git clone
                if FileManager.default.fileExists(atPath: targetURL.appendingPathComponent(".git").path) {
                    // 已存在镜像，直接添加
                } else {
                    let runner = ProcessRunner()
                    _ = try await runner.run(
                        executableURL: URL(fileURLWithPath: "/usr/bin/git"),
                        arguments: ["clone", "--quiet", trimmedURL, targetURL.path],
                        timeout: 120
                    )
                }

                let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? targetURL.lastPathComponent
                    : name.trimmingCharacters(in: .whitespacesAndNewlines)

                onConfirm(finalName, targetURL.path, trimmedURL, analyzeMarkdown, analyzeCode)
                dismiss()
            } catch {
                errorMessage = "克隆失败：\(error.localizedDescription)"
                isCloning = false
            }
        }
    }
}
