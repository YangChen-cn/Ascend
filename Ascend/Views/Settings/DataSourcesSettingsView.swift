import SwiftUI
import UniformTypeIdentifiers

struct DataSourcesSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showImporter = false
    @State private var pendingKind = SourceKind.gitRepository
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("数据源").font(.title2).bold()
                Spacer()
                Menu("添加数据源", systemImage: "plus") {
                    Button("Git 仓库", systemImage: "arrow.triangle.branch", action: addGitRepository)
                    Button("Markdown / Obsidian 目录", systemImage: "doc.text", action: addMarkdownDirectory)
                }
            }
            Text("知境录只扫描你主动添加的目录。未提交代码需要在对应仓库中单独授权。")
                .foregroundStyle(.secondary)

            List {
                ForEach(appState.sources.filter { $0.path != "demo://" }) { source in
                    SourceSettingsRow(source: source)
                }
                .onDelete(perform: deleteSources)
            }
            .listStyle(.inset)

            if appState.sources.allSatisfy({ $0.path == "demo://" }) {
                ContentUnavailableView("还没有真实数据源", systemImage: "externaldrive.badge.plus", description: Text("添加本地 Git 仓库或 Markdown 目录开始自动采集。"))
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        }
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
