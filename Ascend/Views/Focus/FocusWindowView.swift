import SwiftUI

/// 专注悬浮小窗（入定）：焚香计时主界面，紧凑常驻、可置顶。
/// 计时状态由 AppState + FocusSession 持久化，关窗与重启均不丢。
struct FocusWindowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismissWindow) private var dismissWindow

    @AppStorage(FocusPreferences.floatsOnTopKey) private var floatsOnTop = FocusPreferences.defaultFloatsOnTop

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AscendTheme.separator(for: colorScheme))
            content
        }
        .frame(width: 300, height: 446)
        .background(AscendTheme.background(for: colorScheme))
        .background(FocusWindowLevelSetter(floatsOnTop: floatsOnTop))
        .onAppear {
            appState.refreshDailyLessonDay()
        }
        .onExitCommand {
            dismissWindow(id: "focus")
        }
    }

    // MARK: 头部

    private var header: some View {
        HStack(spacing: 8) {
            Text(AscendTheme.isXuanqing ? "入定" : "专注")
                .font(.system(.headline, design: AscendTheme.titleDesign))
                .bold()

            if let session = appState.activeFocusSession {
                CelestialBadge(
                    title: session.phase == .focus ? "焚香中" : "小憩中",
                    style: session.phase == .focus ? .gold : .jade
                )
            }

            Spacer(minLength: 8)

            Button {
                floatsOnTop.toggle()
            } label: {
                Image(systemName: floatsOnTop ? "pin.fill" : "pin")
                    .font(.system(.footnote))
            }
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)
            .foregroundStyle(floatsOnTop ? AscendTheme.gold : .secondary)
            .help(floatsOnTop ? "取消窗口置顶" : "窗口置顶")

            Button {
                dismissWindow(id: "focus")
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)
            .foregroundStyle(.secondary)
            .help("关闭（计时仍在后台进行，Esc）")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        if let session = appState.activeFocusSession {
            FocusActivePane(session: session)
        } else {
            FocusIdlePane()
        }
    }
}
