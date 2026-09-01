import SwiftUI

struct MenuBarAssessmentPreparationStatus: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    private var message: String {
        appState.assessmentPreparationMessage
            ?? "正在生成验证题包；完成后请从菜单栏主动进入验证"
    }

    private var isFailure: Bool {
        message.localizedStandardContains("失败") || message.localizedStandardContains("中断")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if appState.isGeneratingAssessment {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("正在批量备题")
            } else {
                Image(systemName: isFailure ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(isFailure ? MenuBarPalette.cinnabar(colorScheme) : MenuBarPalette.jade(colorScheme))
            }

            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(isFailure ? MenuBarPalette.cinnabar(colorScheme) : MenuBarPalette.secondaryInk(colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if appState.isGeneratingAssessment {
                Button("取消", systemImage: "xmark") {
                    appState.cancelAssessmentGeneration()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(MenuBarPalette.cinnabar(colorScheme))
                .help("取消当前 AI 备题请求")
            } else {
                Button("关闭", systemImage: "xmark") {
                    appState.assessmentPreparationMessage = nil
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(MenuBarPalette.secondaryInk(colorScheme))
                .help("关闭备题状态")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(
            (isFailure ? MenuBarPalette.cinnabar(colorScheme) : MenuBarPalette.jade(colorScheme))
                .opacity(colorScheme == .dark ? 0.10 : 0.07)
        )
    }
}
