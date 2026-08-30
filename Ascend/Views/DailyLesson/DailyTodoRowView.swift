import SwiftUI

/// 待办行：勾选圆环 + 标题 + 到期/知识点徽标；悬停浮现操作（专注、推迟、编辑、删除）。
struct DailyTodoRowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let task: DailyTask
    var showsCompletionTime: Bool = false
    var onEdit: (DailyTask) -> Void = { _ in }

    @State private var isHovered = false
    @State private var checkPulse = false

    private var isCompleted: Bool { task.completedAt != nil }

    var body: some View {
        HStack(spacing: 10) {
            checkButton

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(isCompleted, color: .secondary)
                    .foregroundStyle(isCompleted ? Color.secondary : Color.primary)
                    .lineLimit(2)
                if showsCompletionTime, let completedAt = task.completedAt {
                    Text("完成于 \(completedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            knowledgeChip
            dueBadge

            Spacer(minLength: 0)

            if isHovered, !isCompleted {
                actionButtons
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: AscendTheme.Radius.control, style: .continuous)
                .fill(isHovered ? AscendTheme.hoverSurface(for: colorScheme) : .clear)
        }
        .onHover { hovered in
            guard !reduceMotion else { isHovered = hovered; return }
            withAnimation(.easeOut(duration: 0.15)) { isHovered = hovered }
        }
        .animation(.easeOut(duration: 0.15), value: isCompleted)
    }

    // MARK: 子件

    private var checkButton: some View {
        Button {
            completeWithPulse()
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(
                        isCompleted ? AscendTheme.jade : AscendTheme.border(for: colorScheme),
                        lineWidth: 1.6
                    )
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AscendTheme.jade)
                        .scaleEffect(checkPulse ? 1 : 0.4)
                }
            }
            .frame(width: 20, height: 20)
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help(isCompleted ? "撤销完成" : "标记完成")
        .accessibilityLabel(isCompleted ? "撤销完成：\(task.title)" : "完成：\(task.title)")
    }

    @ViewBuilder
    private var knowledgeChip: some View {
        if let node = appState.knowledgeNode(for: task) {
            Button {
                appState.selectedKnowledgeNodeID = node.id
                appState.selectedSection = .knowledge
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.system(size: 8))
                    Text(node.name)
                        .lineLimit(1)
                }
                .font(.caption2)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(AscendTheme.jade.opacity(colorScheme == .dark ? 0.16 : 0.09))
                .foregroundStyle(AscendTheme.jade)
                .clipShape(.capsule)
            }
            .buttonStyle(.plain)
            .help("查看知识点「\(node.name)」")
        }
    }

    @ViewBuilder
    private var dueBadge: some View {
        if !isCompleted, let dueDate = task.dueDate {
            let bucket = DailyLessonAnalytics.dueBucket(for: dueDate, now: .now)
            switch bucket {
            case .overdue:
                badge(text: "已逾期", color: AscendTheme.cinnabar)
            case .today:
                badge(text: "今天", color: AscendTheme.jade)
            case .tomorrow:
                badge(text: "明天", color: AscendTheme.slate)
            case .upcoming, .undated:
                badge(
                    text: dueDate.formatted(date: .abbreviated, time: .omitted),
                    color: .secondary
                )
            }
        }
    }

    private func badge(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.10))
            .foregroundStyle(color)
            .clipShape(.capsule)
    }

    private var actionButtons: some View {
        HStack(spacing: 2) {
            rowButton("flame", "专注一炷香") {
                appState.startFocusSession(taskID: task.id)
            }
            rowButton("arrow.right.circle", "推迟到明天") {
                appState.postponeTodo(task)
            }
            rowButton("pencil", "编辑") {
                onEdit(task)
            }
            rowButton("trash", "删除") {
                appState.deleteDailyTask(task)
            }
            .foregroundStyle(AscendTheme.cinnabar)
        }
    }

    private func rowButton(_ systemImage: String, _ helpText: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11))
                .frame(width: 24, height: 24)
                .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .help(helpText)
        .accessibilityLabel(helpText)
    }

    private func completeWithPulse() {
        appState.toggleTodo(task)
        guard !reduceMotion else { return }
        checkPulse = false
        withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
            checkPulse = true
        }
    }
}
