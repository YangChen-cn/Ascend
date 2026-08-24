import SwiftUI

struct SourceSettingsRow: View {
    @Environment(AppState.self) private var appState
    @Bindable var source: SourceConfiguration

    private var syncError: String? {
        source.lastSyncError
    }

    private var isRemoteGit: Bool {
        source.kind == .remoteGitRepository || source.kind == .remoteGitMarkdown
    }

    private var analyzedContentSummary: String {
        switch (source.analyzeMarkdown, source.analyzeCode) {
        case (true, true): "Markdown + Code"
        case (true, false): "仅 Markdown"
        case (false, true): "仅 Code"
        case (false, false): "未选择分析内容"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: source.kind.systemImage)
                        .foregroundStyle(AscendTheme.jade)
                    Text(source.name)
                        .font(.headline)

                    // 状态徽章
                    if source.kind == .markdownDirectory {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(source.isEnabled && appState.isCollecting ? AscendTheme.jade : AscendTheme.slate)
                                .frame(width: 6, height: 6)
                            Text(source.isEnabled && appState.isCollecting ? "FSEvents 监听中" : "已暂停监听")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(source.isEnabled && appState.isCollecting ? AscendTheme.jade : .secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background((source.isEnabled && appState.isCollecting ? AscendTheme.jade : AscendTheme.slate).opacity(0.12))
                        .clipShape(Capsule())
                    } else if isRemoteGit {
                        HStack(spacing: 4) {
                            Image(systemName: syncError == nil ? "arrow.triangle.merge" : "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                            if let cursor = source.lastCursor {
                                Text("游标: \(cursor.prefix(7))")
                            } else {
                                Text(syncError == nil ? "待同步" : "同步失败")
                            }
                        }
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(syncError == nil ? AscendTheme.gold : Color.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AscendTheme.gold.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }

                Spacer()

                Toggle("启用此来源", isOn: $source.isEnabled)
                    .labelsHidden()
            }

            Text(source.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if source.kind == .gitRepository {
                Divider()
                Toggle("允许分析未提交工作区的最小 diff 审计片段", isOn: $source.analyzeWorkingTree)
                    .font(.caption)

                HStack {
                    Text("提交作者过滤：")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("留空自动识别 git config，或输入邮箱/姓名", text: $source.authorFilter)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }
            } else if isRemoteGit {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("分析内容")
                        .font(.caption)
                        .bold()
                    Toggle("Markdown 学习笔记", isOn: $source.analyzeMarkdown)
                    Toggle("代码提交", isOn: $source.analyzeCode)
                }
                .font(.caption)

                HStack(spacing: 12) {
                    Text(analyzedContentSummary)
                        .font(.caption)
                        .foregroundStyle(AscendTheme.jade)
                    if let lastSync = source.lastScannedAt {
                        Text("最后同步：\(lastSync.formatted(.dateTime.month().day().hour().minute()))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let cursor = source.lastCursor {
                        Text("最新 commit：\(cursor.prefix(8))")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                if let upstream = source.lastUpstreamReference {
                    Text("upstream：\(upstream)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                if let remoteURL = source.remoteURLString, !remoteURL.isEmpty {
                    Text("远端：\(remoteURL)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }
                if let syncError {
                    Text("同步失败：\(syncError)")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            } else if source.kind == .markdownDirectory {
                if let lastScan = source.lastScannedAt {
                    Text("最后对账扫描：\(lastScan.formatted(.dateTime.month().day().hour().minute()))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("忽略规则（每行一个路径或通配符）：")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                TextField("例如: target/, node_modules/, *.log", text: $source.ignorePatternsText, axis: .vertical)
                    .lineLimit(2...4)
                    .font(.caption.monospaced())
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.02))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.8)
        }
        .padding(.vertical, 4)
        .onChange(of: source.isEnabled) { appState.saveChanges() }
        .onChange(of: source.analyzeWorkingTree) { appState.saveChanges() }
        .onChange(of: source.analyzeMarkdown) { appState.saveChanges() }
        .onChange(of: source.analyzeCode) { appState.saveChanges() }
        .onChange(of: source.authorFilter) { appState.saveChanges() }
        .onChange(of: source.ignorePatternsText) { appState.saveChanges() }
    }
}
