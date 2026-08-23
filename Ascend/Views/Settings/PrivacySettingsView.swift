import SwiftUI
import UniformTypeIdentifiers

struct PrivacySettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var exportDocument = JSONExportDocument()
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var showDeleteConfirmation = false
    @State private var showClearAnalysisConfirmation = false
    @State private var message: String?

    var body: some View {
        Form {
            Section("数据边界") {
                Label("原始数据保留在本机，只向当前模型发送完成分析所需的最小片段。", systemImage: "lock.shield")
                Label("API Key 保存在 Keychain，不进入数据库、日志或导出文件。", systemImage: "key")
                Label("未提交代码需要逐仓库授权。", systemImage: "folder.badge.questionmark")
            }
            Section("备份与迁移") {
                HStack {
                    Button("导出 JSON", systemImage: "square.and.arrow.up", action: exportData)
                    Button("导入 JSON", systemImage: "square.and.arrow.down", action: { showImporter = true })
                }
                Text("导出包含知识体系、评分、证据摘要、设置和模型 ID，但不包含 API Key 或完整源码。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section("危险操作") {
                Button("清除全部分析结果", systemImage: "arrow.counterclockwise", role: .destructive) {
                    showClearAnalysisConfirmation = true
                }
                .confirmationDialog("确定清除全部分析结果？", isPresented: $showClearAnalysisConfirmation) {
                    Button("清除分析结果", role: .destructive, action: clearAnalysisHistory)
                } message: {
                    Text("知识图谱、证据、评分、境界、挑战、日报与审核建议都会删除；AI 接口、API Key、数据源和原始活动将保留，原始活动会恢复为待分析。")
                }
                Button("删除全部本地数据", systemImage: "trash", role: .destructive, action: { showDeleteConfirmation = true })
                    .confirmationDialog("确定删除全部本地数据？", isPresented: $showDeleteConfirmation) {
                        Button("永久删除", role: .destructive, action: deleteAll)
                    } message: {
                        Text("知识图谱、评分、证据、接口档案和 Keychain 密钥都会删除，无法撤销。")
                    }
            }
            if let message { Section { Text(message) } }
        }
        .formStyle(.grouped)
        .fileExporter(
            isPresented: $showExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "知境录-备份"
        ) { result in
            if case .failure(let error) = result { message = error.localizedDescription }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json], allowsMultipleSelection: false, onCompletion: importData)
    }

    private func exportData() {
        do {
            exportDocument = JSONExportDocument(data: try appState.exportJSON())
            showExporter = true
        } catch {
            message = error.localizedDescription
        }
    }

    private func importData(_ result: Result<[URL], Error>) {
        Task {
            do {
                guard let url = try result.get().first else { return }
                let data = try Data(contentsOf: url)
                try await appState.importJSON(data)
                message = "导入完成；API Key 需要重新填写"
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private func deleteAll() {
        Task {
            do {
                try await appState.clearAllData()
                message = "本地数据已删除"
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private func clearAnalysisHistory() {
        do {
            try appState.clearAnalysisHistory()
            message = "分析结果已清除；原始活动与配置均已保留"
        } catch {
            message = error.localizedDescription
        }
    }
}
