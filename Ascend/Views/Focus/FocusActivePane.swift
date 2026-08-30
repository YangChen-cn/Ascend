import SwiftUI

/// 专注进行中的面板：焚香/呼吸主视觉 + 倒计时 + 轮次点 + 控制。
struct FocusActivePane: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let session: FocusSession

    var body: some View {
        VStack(spacing: 14) {
            titleBlock
                .padding(.top, 14)

            phaseVisual
                .frame(height: 96)

            remainingLabel

            roundDots

            controls
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: 标题

    private var titleBlock: some View {
        VStack(spacing: 4) {
            Text(session.phase == .focus ? "一炷香" : "小憩片刻")
                .font(.system(.title3, design: AscendTheme.titleDesign))
                .bold()
            if let taskTitle = session.taskID.flatMap({ appState.dailyTaskByID[$0]?.title }) {
                Text(taskTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: 主视觉

    @ViewBuilder
    private var phaseVisual: some View {
        if session.phase == .focus {
            IncenseBurnView(
                progress: burnProgress,
                isBurning: session.pausedAt == nil
            )
        } else {
            RestBreathView()
                .frame(width: 96, height: 96)
        }
    }

    private var burnProgress: Double {
        let remaining = FocusEngine.remainingSeconds(for: session, now: appState.focusTick)
        guard session.plannedSeconds > 0 else { return 0 }
        return Double(session.plannedSeconds - remaining) / Double(session.plannedSeconds)
    }

    // MARK: 倒计时

    private var remainingSeconds: Int {
        FocusEngine.remainingSeconds(for: session, now: appState.focusTick)
    }

    private var remainingLabel: some View {
        Text(FocusGlanceCardView.format(seconds: remainingSeconds))
            .font(.system(size: 40, weight: .light, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(session.phase == .focus ? AscendTheme.gold : AscendTheme.jade)
            .contentTransition(.numericText())
            .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: remainingSeconds)
            .accessibilityLabel("剩余 \(remainingSeconds / 60) 分 \(remainingSeconds % 60) 秒")
    }

    // MARK: 轮次

    private var roundDots: some View {
        let completed = appState.todayCompletedFocusCount()
        let perLongBreak = max(1, appState.focusPreferences.sessionsPerLongBreak)
        return HStack(spacing: 6) {
            ForEach(0..<perLongBreak, id: \.self) { index in
                Circle()
                    .fill(index < completed ? AscendTheme.gold : AscendTheme.gold.opacity(0.16))
                    .frame(width: 6, height: 6)
            }
            Text("第 \(completed + 1) 炷")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日已完成 \(completed) 炷香")
    }

    // MARK: 控制

    private var controls: some View {
        HStack(spacing: 10) {
            if session.pausedAt == nil {
                Button("暂停") {
                    appState.pauseFocusSession()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.space, modifiers: [])
            } else {
                Button("继续") {
                    appState.resumeFocusSession()
                }
                .buttonStyle(.borderedProminent)
                .tint(AscendTheme.jade)
                .keyboardShortcut(.space, modifiers: [])
            }

            Button {
                appState.interruptFocusSession()
            } label: {
                Text("放弃")
            }
            .buttonStyle(.bordered)
            .tint(AscendTheme.cinnabar)
        }
    }
}
