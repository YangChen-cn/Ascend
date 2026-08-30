import SwiftUI

/// 今日页的专注速览卡：今日焚香统计 + 入定入口；有进行中的会话时显示玉环倒计时。
struct FocusGlanceCardView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(AscendTheme.gold)
                .frame(width: 38, height: 38)
                .background(AscendTheme.gold.opacity(0.10), in: .rect(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(AscendTheme.isXuanqing ? "入定 · 焚香计时" : "专注模式")
                    .font(.system(.headline, design: AscendTheme.titleDesign))
                Text(statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let session = appState.activeFocusSession, session.phase == .focus {
                miniRing(progress: focusProgress(session), remaining: remainingText)
            }

            Button {
                appState.isPresentingFocusImmersion = true
            } label: {
                Text(appState.activeFocusSession == nil ? "入定" : "查看")
            }
            .buttonStyle(.borderedProminent)
            .tint(AscendTheme.gold)
            .controlSize(.small)
            .help("打开入定沉浸页")
        }
    }

    private var statusLine: String {
        if let session = appState.activeFocusSession {
            let taskTitle = session.taskID.flatMap { appState.dailyTaskByID[$0]?.title }
            let phaseText = session.phase == .focus ? "一炷香燃至" : "小憩"
            let taskText = taskTitle.map { " · \($0)" } ?? ""
            return "\(phaseText) \(remainingText)\(taskText)"
        }
        let count = appState.todayCompletedFocusCount()
        let minutes = appState.todayFocusMinutes()
        guard count > 0 || minutes > 0 else {
            return AscendTheme.isXuanqing ? "燃一炷香，专注当下" : "用一段不受打扰的时间深入学习"
        }
        return "今日 \(count) 炷香 · \(minutes) 分钟"
    }

    private var remainingText: String {
        guard let remaining = appState.focusRemainingSeconds else { return "--:--" }
        return Self.format(seconds: remaining)
    }

    private func focusProgress(_ session: FocusSession) -> Double {
        let remaining = FocusEngine.remainingSeconds(for: session, now: appState.focusTick)
        guard session.plannedSeconds > 0 else { return 0 }
        return Double(session.plannedSeconds - remaining) / Double(session.plannedSeconds)
    }

    private func miniRing(progress: Double, remaining: String) -> some View {
        ZStack {
            Circle()
                .strokeBorder(AscendTheme.jade.opacity(0.18), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(AscendTheme.jadeGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 34, height: 34)
        .overlay {
            Text(remaining)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .monospacedDigit()
        }
        .accessibilityLabel("剩余 \(remaining)")
    }

    static func format(seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
