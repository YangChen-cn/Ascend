import SwiftUI

/// 日课快速新增输入框：回车即存为今日待办。
struct DailyTaskQuickAddField: View {
    @Binding var text: String
    let onSubmit: () -> Void
    @FocusState.Binding var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle")
                .foregroundStyle(AscendTheme.jade)
                .font(.subheadline)

            TextField("记一件今日要做的事…", text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isFocused)
                .onSubmit(onSubmit)

            if !text.isEmpty {
                Button {
                    submit()
                } label: {
                    Image(systemName: "arrow.return.left")
                        .font(.caption.bold())
                }
                .buttonStyle(.borderless)
                .foregroundStyle(AscendTheme.jade)
                .help("回车快速新增（详细设置请用新增按钮）")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .ascendGlass(
            in: RoundedRectangle(cornerRadius: AscendTheme.Radius.control, style: .continuous),
            tint: AscendTheme.jade.opacity(0.06),
            interactive: true
        )
        .animation(.easeOut(duration: 0.18), value: text.isEmpty)
    }

    private func submit() {
        onSubmit()
        isFocused = false
    }
}
