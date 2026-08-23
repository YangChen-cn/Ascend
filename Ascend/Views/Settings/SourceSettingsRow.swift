import SwiftUI

struct SourceSettingsRow: View {
    @Environment(AppState.self) private var appState
    @Bindable var source: SourceConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(source.name, systemImage: source.kind.systemImage)
                    .bold()
                Spacer()
                Toggle("启用", isOn: $source.isEnabled)
                    .labelsHidden()
            }
            Text(source.path)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if source.kind == .gitRepository {
                Toggle("允许分析未提交工作区的最小 diff", isOn: $source.analyzeWorkingTree)
                HStack {
                    Text("提交作者过滤：")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    TextField("留空自动识别 git config，或输入邮箱/姓名", text: $source.authorFilter)
                        .textFieldStyle(.roundedBorder)
                        .font(.callout)
                }
            }
            TextField("忽略规则（每行一个）", text: $source.ignorePatternsText, axis: .vertical)
                .lineLimit(2...5)
                .font(.callout.monospaced())
        }
        .padding(.vertical, 6)
        .onChange(of: source.isEnabled) { appState.saveChanges() }
        .onChange(of: source.analyzeWorkingTree) { appState.saveChanges() }
        .onChange(of: source.authorFilter) { appState.saveChanges() }
        .onChange(of: source.ignorePatternsText) { appState.saveChanges() }
    }
}
