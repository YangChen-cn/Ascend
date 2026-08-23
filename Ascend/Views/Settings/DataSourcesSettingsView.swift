import SwiftUI
import UniformTypeIdentifiers

struct DataSourcesSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showImporter = false
    @State private var pendingKind = SourceKind.gitRepository
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("研习数据源")
                        .font(.title2)
                        .bold()
                    Text("知境录仅扫描你主动授权的本地目录。未提交代码改动需单独在仓库中勾选授权。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button(action: addGitRepository) {
                        Label("Git 代码仓库…", systemImage: "arrow.triangle.branch")
                    }
                    Button(action: addMarkdownDirectory) {
                        Label("Markdown / 笔记目录…", systemImage: "doc.text")
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
                        Text("尚未连接真实数据源")
                            .font(.headline)
                        Text("点击右上角添加本地 Git 仓库或 Markdown 笔记目录，系统将按时安全采集研习活动。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 360)
                    }

                    HStack(spacing: 12) {
                        Button("添加 Git 仓库", systemImage: "arrow.triangle.branch", action: addGitRepository)
                            .buttonStyle(.bordered)
                        Button("添加 Markdown 目录", systemImage: "doc.text", action: addMarkdownDirectory)
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
    }

    private func addGitRepository() {
        pendingKind = .gitRepository
        showImporter = true
    }

    private func addMarkdownDirectory() {
        pendingKind = .markdownDirectory
        showImporter = true
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
