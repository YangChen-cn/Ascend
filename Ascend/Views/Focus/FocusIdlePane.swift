import SwiftUI

/// 无会话时的空闲面板：焚香静置 + 时长选择 + 任务绑定 + 开始按钮。
struct FocusIdlePane: View {
    @Environment(AppState.self) private var appState

    @State private var selectedMinutes: Int
    @State private var selectedTaskID: UUID?

    init() {
        _selectedMinutes = State(initialValue: FocusPreferences.current().focusMinutes)
    }

    var body: some View {
        VStack(spacing: 12) {
            IncenseBurnView(progress: 0, isBurning: false)
                .frame(height: 84)
                .padding(.top, 12)

            summaryBlock

            durationPicker
            taskPicker

            controls
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            selectedMinutes = appState.focusPreferences.focusMinutes
        }
    }

    // MARK: 摘要

    private var summaryBlock: some View {
        VStack(spacing: 3) {
            Text("焚香一炷 · 不受打扰")
                .font(.system(.subheadline, design: AscendTheme.titleDesign))
                .bold()
            Text(summaryLine)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var summaryLine: String {
        let count = appState.todayCompletedFocusCount()
        let minutes = appState.todayFocusMinutes()
        guard count > 0 || minutes > 0 else {
            return AscendTheme.isXuanqing ? "拾一卷书，燃一炷香" : "选一段时长，开始深入学习"
        }
        return "今日已燃 \(count) 炷 · \(minutes) 分钟"
    }

    // MARK: 时长

    private var durationPicker: some View {
        HStack(spacing: 6) {
            ForEach([15, 25, 45], id: \.self) { minutes in
                DurationChip(
                    minutes: minutes,
                    isSelected: selectedMinutes == minutes,
                    action: { updateMinutes(minutes) }
                )
            }
            Spacer(minLength: 4)
            Stepper {
                Text("\(selectedMinutes) 分")
                    .font(.caption)
                    .monospacedDigit()
            } onIncrement: {
                updateMinutes(selectedMinutes + 5)
            } onDecrement: {
                updateMinutes(selectedMinutes - 5)
            }
            .fixedSize()
        }
        .padding(.horizontal, 14)
    }

    // MARK: 任务绑定

    @ViewBuilder
    private var taskPicker: some View {
        let (open, _) = appState.todayTodoGroups()
        if !open.isEmpty {
            Picker("今日功课", selection: $selectedTaskID) {
                Text("不绑定，自由专注").tag(UUID?.none)
                ForEach(open.prefix(6)) { task in
                    Text(task.title).tag(UUID?.some(task.id))
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
        }
    }

    // MARK: 控制

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                appState.startFocusSession(minutes: selectedMinutes, taskID: selectedTaskID)
            } label: {
                Label("入定", systemImage: "flame.fill")
                    .frame(width: 92)
            }
            .buttonStyle(.borderedProminent)
            .tint(AscendTheme.gold)
            .keyboardShortcut(.defaultAction)

            Button("小憩") {
                appState.startRestSession()
            }
            .buttonStyle(.bordered)
            .disabled(appState.todayCompletedFocusCount() == 0)
            .help("先完成一炷香再小憩")
        }
    }

    // MARK: 辅助

    private func updateMinutes(_ minutes: Int) {
        let clamped = minutes.clamped(to: FocusPreferences.focusMinutesRange)
        selectedMinutes = clamped
        appState.updateFocusPreferences { $0.focusMinutes = clamped }
    }
}

/// 时长预设 chip。
private struct DurationChip: View {
    let minutes: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(minutes) 分")
                .font(.footnote)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .background(isSelected ? AscendTheme.gold.opacity(0.16) : Color.primary.opacity(0.05))
        .foregroundStyle(isSelected ? AscendTheme.gold : .primary)
        .clipShape(.capsule)
        .overlay {
            Capsule().strokeBorder(isSelected ? AscendTheme.gold.opacity(0.5) : .clear, lineWidth: 1)
        }
        .accessibilityLabel("\(minutes) 分钟")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
