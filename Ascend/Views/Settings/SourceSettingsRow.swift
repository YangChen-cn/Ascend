import SwiftUI

struct SourceSettingsRow: View {
    @Environment(AppState.self) private var appState
    @Bindable var source: SourceConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: source.kind.systemImage)
                        .foregroundStyle(AscendTheme.jade)
                    Text(source.name)
                        .font(.headline)
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
        .onChange(of: source.authorFilter) { appState.saveChanges() }
        .onChange(of: source.ignorePatternsText) { appState.saveChanges() }
    }
}
