import SwiftUI

/// 聚合 Git 提交中的人工文件范围选择。空选择保留自动相关性抽取，选择后严格限定审计范围。
struct ChallengeCommitFilePicker: View {
    @Environment(\.colorScheme) private var colorScheme

    let files: [String]
    @Binding var selection: Set<String>
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label("本次核验文件", systemImage: "doc.on.doc")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                if !files.isEmpty {
                    Button("全选", action: selectAll)
                        .buttonStyle(.link)
                        .controlSize(.small)
                    Button("清除", action: clearSelection)
                        .buttonStyle(.link)
                        .controlSize(.small)
                        .disabled(selection.isEmpty)
                }
            }

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在读取该提交的文件…")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(AscendTheme.cinnabar)
            } else {
                Text(selection.isEmpty
                     ? "未选择时按挑战目标自动抽取；也可手动勾选一个或多个文件。"
                     : "已选择 \(selection.count) 个文件，AI 只核验这些文件。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        ForEach(files, id: \.self) { path in
                            Toggle(path, isOn: binding(for: path))
                                .toggleStyle(.checkbox)
                                .font(.caption)
                                .help(path)
                                .accessibilityHint("选中后，本次挑战核验只读取所选文件")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 132)
            }
        }
        .padding(10)
        .background(
            AscendTheme.subtleSurface(for: colorScheme),
            in: RoundedRectangle(cornerRadius: AscendTheme.Radius.control)
        )
    }

    private func binding(for path: String) -> Binding<Bool> {
        Binding(
            get: { selection.contains(path) },
            set: { isSelected in
                if isSelected {
                    selection.insert(path)
                } else {
                    selection.remove(path)
                }
            }
        )
    }

    private func selectAll() {
        selection = Set(files)
    }

    private func clearSelection() {
        selection.removeAll()
    }
}
