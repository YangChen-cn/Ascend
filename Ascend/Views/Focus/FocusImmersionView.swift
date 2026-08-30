import SwiftUI

/// 入定沉浸页：覆盖主窗口的玄墨舞台。
/// 打开时播放古风开场——墨纱渐显、竖排「入定」、朱砂盖印，随后焚香与倒计时淡入。
/// 专注本体是后台计时（结束时系统通知）；本页只是随时可关的仪式性入口。
struct FocusImmersionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var showsOpeningTitle = true
    @State private var showsContent = false
    @State private var sealProgress: Double = 0

    @State private var selectedMinutes: Int
    @State private var selectedTaskID: UUID?

    init() {
        _selectedMinutes = State(initialValue: FocusPreferences.current().focusMinutes)
    }

    var body: some View {
        ZStack {
            inkBackground

            if showsContent {
                mainLayout
                    .transition(.opacity)
            }

            if showsOpeningTitle {
                openingTitle
                    .transition(.opacity.combined(with: .scale(scale: 1.04)))
            }
        }
        .overlay {
            // 暗角：给玄墨舞台一点纵深，避免"纯黑平面"
            RadialGradient(
                colors: [.clear, .black.opacity(0.42)],
                center: .center,
                startRadius: 220,
                endRadius: 920
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .environment(\.colorScheme, .dark)
        .task { await playOpeningSequence() }
        // 进入专注态 3 秒后自动收场：先淡出沉浸层，再关闭整个主窗口，
        // 让应用退回菜单栏纯后台；会话结束（id 变 nil）时该任务自动取消。
        .task(id: appState.activeFocusSession?.id) {
            guard appState.activeFocusSession != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            appState.isPresentingFocusImmersion = false
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.4))
                dismissWindow(id: "main")
            }
        }
    }

    // MARK: 开场动画

    /// 确定性时序：盖印 → 凝视 → 淡入正文。用 task + sleep 而非动画回调，避免取消事件干扰。
    private func playOpeningSequence() async {
        selectedMinutes = appState.focusPreferences.focusMinutes
        guard !reduceMotion else {
            showsOpeningTitle = false
            showsContent = true
            return
        }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
            sealProgress = 1
        }
        try? await Task.sleep(for: .seconds(1.05))
        withAnimation(.easeInOut(duration: 0.5)) {
            showsOpeningTitle = false
            showsContent = true
        }
    }

    private var openingTitle: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 8) {
                    Text("入")
                        .font(.system(size: 46, weight: .medium, design: .serif))
                    Text("定")
                        .font(.system(size: 46, weight: .medium, design: .serif))
                }
                .foregroundStyle(Color(white: 0.93))

                ClassicalSealMark(text: "静", style: .cinnabar, size: 30)
                    .scaleEffect(sealProgress == 1 ? 1 : 1.5)
                    .opacity(sealProgress)
                    .rotationEffect(.degrees(sealProgress == 1 ? -2 : -9))
                    .offset(y: 4)
            }

            Text("焚香一炷 · 诸事暂歇")
                .font(.system(.callout, design: .serif))
                .foregroundStyle(Color(white: 0.62))
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: 背景

    private var inkBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.066, green: 0.088, blue: 0.082),
                    Color(red: 0.03, green: 0.046, blue: 0.042)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            // 暖芯：香案中心的一点火光余温
            RadialGradient(
                colors: [AscendTheme.gold.opacity(0.07), .clear],
                center: .center,
                startRadius: 30,
                endRadius: 420
            )
            InkLandscapeWatermark(height: 160, opacity: 0.18)
                .frame(maxWidth: 880)
                .opacity(AscendTheme.isXuanqing ? 1 : 0)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 10)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    /// 一轮淡月：悬于舞台上方，与远山、焚香构成中式构图。
    private var moon: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? nil : 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let breath = reduceMotion
                ? 0.5
                : 0.5 + 0.5 * sin(timeline.date.timeIntervalSinceReferenceDate * 2 * .pi / 9)
            return ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AscendTheme.gold.opacity(0.10 + 0.05 * breath), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 70
                        )
                    )
                    .frame(width: 150, height: 150)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.97), Color(white: 0.86, opacity: 0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                    .shadow(color: AscendTheme.gold.opacity(0.3), radius: 14)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: 正文

    private var mainLayout: some View {
        ZStack {
            moon
                .offset(y: -148)

            VStack(spacing: 0) {
                header
                Spacer()
                if let session = appState.activeFocusSession {
                    activeBlock(session)
                } else {
                    idleBlock
                }
                Spacer()
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 20)
        .padding(.bottom, 26)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("入定")
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Color(white: 0.9))
            if let session = appState.activeFocusSession {
                Text(session.phase == .focus ? "焚香中" : "小憩中")
                    .font(.caption)
                    .foregroundStyle(Color(white: 0.55))
            }
            Spacer()
            Button {
                close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)
            .foregroundStyle(Color(white: 0.55))
            .help("收起入定（计时仍在后台进行）")
        }
    }

    // MARK: 进行中

    private func activeBlock(_ session: FocusSession) -> some View {
        VStack(spacing: 18) {
            if let taskTitle = session.taskID.flatMap({ appState.dailyTaskByID[$0]?.title }) {
                Text(taskTitle)
                    .font(.callout)
                    .foregroundStyle(Color(white: 0.62))
                    .lineLimit(1)
            }

            Group {
                if session.phase == .focus {
                    IncenseBurnView(
                        progress: burnProgress(session),
                        isBurning: session.pausedAt == nil
                    )
                    .frame(height: 170)
                } else {
                    RestBreathView()
                        .frame(width: 130, height: 124)
                }
            }
            .frame(maxWidth: 560)

            Text(FocusGlanceCardView.format(seconds: remaining(session)))
                .font(.system(size: 58, weight: .thin, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(session.phase == .focus ? AscendTheme.gold : AscendTheme.jade)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: remaining(session))

            roundDots

            activeControls(session)

            Text("此窗稍后自动收起并关闭 · 计时与结束通知照常")
                .font(.caption2)
                .foregroundStyle(Color(white: 0.4))
        }
    }

    private var roundDots: some View {
        let completed = appState.todayCompletedFocusCount()
        let perLongBreak = max(1, appState.focusPreferences.sessionsPerLongBreak)
        return HStack(spacing: 7) {
            ForEach(0..<perLongBreak, id: \.self) { index in
                Circle()
                    .fill(index < completed ? AscendTheme.gold : AscendTheme.gold.opacity(0.18))
                    .frame(width: 6, height: 6)
            }
            Text("第 \(completed + 1) 炷")
                .font(.caption)
                .foregroundStyle(Color(white: 0.55))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日已完成 \(completed) 炷香")
    }

    private func activeControls(_ session: FocusSession) -> some View {
        HStack(spacing: 12) {
            if session.pausedAt == nil {
                Button("暂停") {
                    appState.pauseFocusSession()
                }
                .keyboardShortcut(.space, modifiers: [])
            } else {
                Button("继续") {
                    appState.resumeFocusSession()
                }
                .keyboardShortcut(.space, modifiers: [])
                .tint(AscendTheme.jade)
            }

            Button("放弃", role: .destructive) {
                appState.interruptFocusSession()
            }
            .tint(AscendTheme.cinnabar)
        }
        .controlSize(.large)
        .tint(Color(white: 0.9))
    }

    // MARK: 空闲

    private var idleBlock: some View {
        VStack(spacing: 18) {
            // 静置的香：香头备好微光与青烟，等待点燃
            IncenseBurnView(progress: 0, isBurning: true)
                .frame(maxWidth: 560)
                .frame(height: 150)

            VStack(spacing: 6) {
                Text("焚香一炷 · 不受打扰")
                    .font(.system(.title2, design: .serif))
                    .foregroundStyle(Color(white: 0.92))
                Text(idleSummary)
                    .font(.callout)
                    .foregroundStyle(Color(white: 0.55))
            }

            durationPicker

            if !openTodos.isEmpty {
                Picker("今日功课", selection: $selectedTaskID) {
                    Text("不绑定，自由专注").tag(UUID?.none)
                    ForEach(openTodos.prefix(6)) { task in
                        Text(task.title).tag(UUID?.some(task.id))
                    }
                }
                .labelsHidden()
                .frame(width: 340)
            }

            HStack(spacing: 14) {
                Button {
                    appState.startFocusSession(minutes: selectedMinutes, taskID: selectedTaskID)
                } label: {
                    Label("入定", systemImage: "flame.fill")
                        .frame(width: 104)
                }
                .buttonStyle(.borderedProminent)
                .tint(AscendTheme.gold)
                .keyboardShortcut(.defaultAction)

                Button("小憩") {
                    appState.startRestSession()
                }
                .disabled(appState.todayCompletedFocusCount() == 0)
                .help("先完成一炷香再小憩")
            }
            .controlSize(.large)
        }
    }

    private var idleSummary: String {
        let count = appState.todayCompletedFocusCount()
        let minutes = appState.todayFocusMinutes()
        guard count > 0 || minutes > 0 else {
            return AscendTheme.isXuanqing ? "拾一卷书，燃一炷香" : "选一段时长，开始深入学习"
        }
        return "今日已燃 \(count) 炷 · \(minutes) 分钟"
    }

    private var openTodos: [DailyTask] {
        appState.todayTodoGroups().open
    }

    private var durationPicker: some View {
        HStack(spacing: 8) {
            ForEach([15, 25, 45], id: \.self) { minutes in
                ImmersionDurationChip(
                    minutes: minutes,
                    isSelected: selectedMinutes == minutes,
                    action: { updateMinutes(minutes) }
                )
            }

            HStack(spacing: 5) {
                TextField("自定义", value: $selectedMinutes, format: .number.grouping(.never))
                    .multilineTextAlignment(.center)
                    .frame(width: 42)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                    .monospacedDigit()
                    .onSubmit { updateMinutes(selectedMinutes) }
                Text("分")
                    .font(.caption)
                    .foregroundStyle(Color(white: 0.55))
                Stepper("", onIncrement: {
                    updateMinutes(selectedMinutes + 5)
                }, onDecrement: {
                    updateMinutes(selectedMinutes - 5)
                })
                .labelsHidden()
                .fixedSize()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isCustomDuration ? AscendTheme.gold.opacity(0.14) : Color.white.opacity(0.07))
            .clipShape(.capsule)
            .overlay {
                Capsule().strokeBorder(
                    isCustomDuration ? AscendTheme.gold.opacity(0.55) : .clear,
                    lineWidth: 1
                )
            }
            .help("自定义时长（1–180 分钟），输入后回车生效")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("专注时长，当前 \(selectedMinutes) 分钟")
    }

    private var isCustomDuration: Bool {
        ![15, 25, 45].contains(selectedMinutes)
    }

    // MARK: 辅助

    private var remaining: (FocusSession) -> Int {
        { FocusEngine.remainingSeconds(for: $0, now: appState.focusTick) }
    }

    private func burnProgress(_ session: FocusSession) -> Double {
        let remaining = FocusEngine.remainingSeconds(for: session, now: appState.focusTick)
        guard session.plannedSeconds > 0 else { return 0 }
        return Double(session.plannedSeconds - remaining) / Double(session.plannedSeconds)
    }

    private func updateMinutes(_ minutes: Int) {
        let clamped = minutes.clamped(to: FocusPreferences.focusMinutesRange)
        selectedMinutes = clamped
        appState.updateFocusPreferences { $0.focusMinutes = clamped }
    }

    private func close() {
        appState.isPresentingFocusImmersion = false
    }
}

/// 沉浸页时长 chip：玄墨底上的暖金选中态。
private struct ImmersionDurationChip: View {
    let minutes: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(minutes) 分")
                .font(.callout)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(isSelected ? AscendTheme.gold.opacity(0.2) : Color.white.opacity(0.07))
        .foregroundStyle(isSelected ? AscendTheme.gold : Color(white: 0.82))
        .clipShape(.capsule)
        .overlay {
            Capsule().strokeBorder(isSelected ? AscendTheme.gold.opacity(0.55) : .clear, lineWidth: 1)
        }
        .accessibilityLabel("\(minutes) 分钟")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
