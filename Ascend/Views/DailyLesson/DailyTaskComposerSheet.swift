import SwiftUI

/// 日课任务编辑器：⌘N 快捷新增、行内编辑与习惯定义共用。
struct DailyTaskComposerSheet: View {
    enum Mode {
        case create(DailyTaskKind)
        case edit(DailyTask)
    }

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var kind: DailyTaskKind = .todo
    @State private var title = ""
    @State private var noteText = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date.now
    @State private var selectedWeekdays: Set<Int> = [2, 3, 4, 5, 6] // 周一…周五
    @State private var selectedNodeID: UUID?

    @FocusState private var isTitleFocused: Bool

    init(initialKind: DailyTaskKind = .todo) {
        mode = .create(initialKind)
    }

    init(editing task: DailyTask) {
        mode = .edit(task)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeaderView(
                isEditing ? "编辑任务" : "新增任务",
                subtitle: kind == .habit ? "每日重复，完成即打卡" : "写下今天要完成的学习目标",
                systemImage: "square.and.pencil"
            ) {
                EmptyView()
            }

            VStack(alignment: .leading, spacing: 12) {
                titleField
                kindPicker

                if kind == .todo {
                    dueDatePicker
                } else {
                    weekdayPicker
                }

                noteField
                knowledgePicker
            }

            Spacer(minLength: 0)

            HStack {
                Button("取消", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(action: save) {
                    Text(isEditing ? "保存" : "添加")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420, height: 470)
        .onAppear(perform: populateForMode)
        .onAppear {
            isTitleFocused = true
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    // MARK: 字段

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 5) {
            fieldLabel("标题")
            TextField("例如：完成页面置换算法笔记", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($isTitleFocused)
                .onSubmit(save)
        }
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            fieldLabel("类型")
            Picker("类型", selection: $kind) {
                ForEach(DailyTaskKind.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isEditing)
            .onChange(of: kind) { _, _ in
                isTitleFocused = true
            }
        }
    }

    private var dueDatePicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            Toggle(isOn: $hasDueDate) {
                fieldLabel("截止日期")
            }
            .toggleStyle(.checkbox)
            if hasDueDate {
                DatePicker(
                    "截止日期",
                    selection: $dueDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
            }
        }
    }

    private var weekdayPicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            fieldLabel("重复于")
            HStack(spacing: 6) {
                ForEach(weekdaySymbols, id: \.offset) { item in
                    let isSelected = selectedWeekdays.contains(item.offset)
                    Button {
                        if isSelected {
                            selectedWeekdays.remove(item.offset)
                        } else {
                            selectedWeekdays.insert(item.offset)
                        }
                    } label: {
                        Text(item.symbol)
                            .font(.caption)
                            .frame(width: 30, height: 26)
                    }
                    .buttonStyle(.plain)
                    .background(isSelected ? AscendTheme.jade.opacity(0.16) : Color.primary.opacity(0.05))
                    .foregroundStyle(isSelected ? AscendTheme.jade : .secondary)
                    .clipShape(.rect(cornerRadius: 6))
                    .help(item.name)
                }
                Spacer()
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 5) {
            fieldLabel("备注（可选）")
            TextField("补充说明", text: $noteText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
        }
    }

    @ViewBuilder
    private var knowledgePicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            fieldLabel("关联知识点（可选）")
            KnowledgeNodePicker(selectedNodeID: $selectedNodeID)
        }
    }

    // MARK: 逻辑

    private var weekdaySymbols: [(offset: Int, symbol: String, name: String)] {
        [
            (2, "一", "周一"), (3, "二", "周二"), (4, "三", "周三"), (5, "四", "周四"),
            (6, "五", "周五"), (7, "六", "周六"), (1, "日", "周日")
        ]
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func populateForMode() {
        switch mode {
        case .create(let initialKind):
            kind = initialKind
        case .edit(let task):
            kind = task.kind
            title = task.title
            noteText = task.noteText ?? ""
            selectedNodeID = task.knowledgeNodeID
            if let due = task.dueDate {
                hasDueDate = true
                dueDate = due
            }
            if task.isHabit {
                selectedWeekdays = []
                for bit in 1...7 where task.weekdayMask & (1 << (bit - 1)) != 0 {
                    selectedWeekdays.insert(bit)
                }
            }
        }
    }

    private func computedWeekdayMask() -> Int {
        var mask = 0
        for weekday in selectedWeekdays {
            mask |= 1 << (weekday - 1)
        }
        return mask
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        switch mode {
        case .create:
            appState.addDailyTask(
                title: trimmed,
                kind: kind,
                noteText: noteText.isEmpty ? nil : noteText,
                dueDate: kind == .todo && hasDueDate ? dueDate : nil,
                weekdayMask: kind == .habit ? computedWeekdayMask() : 0,
                knowledgeNodeID: selectedNodeID
            )
        case .edit(let task):
            appState.updateDailyTask(
                task,
                title: trimmed,
                noteText: noteText.isEmpty ? nil : noteText,
                dueDate: kind == .todo && hasDueDate ? dueDate : nil,
                weekdayMask: kind == .habit ? computedWeekdayMask() : 0,
                knowledgeNodeID: selectedNodeID
            )
        }
        dismiss()
    }
}

/// 知识点选择器：搜索过滤 + 按领域分组；空库时给出引导文案。
struct KnowledgeNodePicker: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedNodeID: UUID?
    @State private var filterText = ""

    private var filteredNodes: [KnowledgeNode] {
        let keyword = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        let nodes = appState.knowledgeNodes
        guard !keyword.isEmpty else { return nodes }
        return nodes.filter { $0.name.localizedCaseInsensitiveContains(keyword) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("搜索知识点", text: $filterText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                if selectedNodeID != nil {
                    Button {
                        selectedNodeID = nil
                    } label: {
                        Text("清除")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05))
            .clipShape(.rect(cornerRadius: 6))

            if appState.knowledgeNodes.isEmpty {
                Text("暂无知识点。采集并分析学习材料后即可关联。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(filteredNodes, id: \.id) { node in
                            nodeRow(node)
                        }
                    }
                }
                .frame(maxHeight: 128)
            }
        }
    }

    private func nodeRow(_ node: KnowledgeNode) -> some View {
        let isSelected = selectedNodeID == node.id
        return Button {
            selectedNodeID = isSelected ? nil : node.id
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AscendTheme.jade : .secondary)
                    .font(.caption)
                VStack(alignment: .leading, spacing: 1) {
                    Text(node.name)
                        .font(.callout)
                        .lineLimit(1)
                    Text(node.domain)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isSelected ? AscendTheme.hoverSurface(for: colorScheme) : .clear)
            .clipShape(.rect(cornerRadius: 6))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
