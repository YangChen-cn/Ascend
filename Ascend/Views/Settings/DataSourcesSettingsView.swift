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
                    Button(action: addRemoteGitMarkdown) {
                        Label("远程 Git 笔记仓库…", systemImage: "icloud.and.arrow.down")
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
                        Text("点击右上角添加本地 Git 仓库、本地 Markdown 笔记目录或远程 Git 笔记，系统将安全采集研习活动。")
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
                        Button("添加远程 Git 笔记", systemImage: "icloud.and.arrow.down", action: addRemoteGitMarkdown)
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
            AddRemoteGitSourceSheet { name, path in
                do {
                    try appState.addSource(name: name, kind: .remoteGitMarkdown, path: path)
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

    private func addRemoteGitMarkdown() {
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

// MARK: - 远程 Git 笔记添加面板

private struct AddRemoteGitSourceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var path: String = ""
    @State private var showFolderPicker = false

    let onConfirm: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("添加远程 Git 笔记数据源")
                    .font(.headline)
                Spacer()
                Button("取消", role: .cancel) { dismiss() }
            }

            Text("指定同步 Ubuntu VM 或远端推送的 Git 笔记仓库本地镜像路径。知境录将基于 Commit SHA 增量提取 Markdown Diff。")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("来源名称")
                    .font(.caption.bold())
                TextField("例如：Ubuntu VM 研习笔记", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("仓库本地路径")
                    .font(.caption.bold())
                HStack {
                    TextField("/Users/.../vm-notes", text: $path)
                        .textFieldStyle(.roundedBorder)
                    Button("浏览…") { showFolderPicker = true }
                        .buttonStyle(.bordered)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("完成添加") {
                    let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? URL(fileURLWithPath: path).lastPathComponent
                        : name.trimmingCharacters(in: .whitespacesAndNewlines)
                    onConfirm(finalName, path.trimmingCharacters(in: .whitespacesAndNewlines))
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(AscendTheme.jade)
                .disabled(path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22)
        .frame(minWidth: 460)
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if let url = try? result.get().first {
                path = url.path
                if name.isEmpty {
                    name = url.lastPathComponent
                }
            }
        }
    }
}
