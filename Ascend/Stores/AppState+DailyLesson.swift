import Foundation
import SwiftData

// MARK: - 日课（今日待办 + 习惯打卡）
//
// 日课是用户自报的执行层：完成与否绝不写入 EvidenceRecord、ScoreLedger 或掌握度；
// 与知识点的关联只做信息展示与行动引导。

extension AppState {
    // MARK: 任务管理

    @discardableResult
    func addDailyTask(
        title: String,
        kind: DailyTaskKind = .todo,
        noteText: String? = nil,
        dueDate: Date? = nil,
        weekdayMask: Int = 0,
        knowledgeNodeID: UUID? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DailyTask? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            statusMessage = "请先填写要做的事"
            return nil
        }
        if kind == .habit, knowledgeNodeID != nil, nodeByID[knowledgeNodeID!] == nil {
            statusMessage = "关联的知识点不存在"
            return nil
        }
        let task = DailyTask(
            kind: kind,
            title: trimmedTitle,
            noteText: normalizedNote(noteText),
            createdAt: now,
            dueDate: dueDate.map { calendar.startOfDay(for: $0) },
            weekdayMask: kind == .habit ? weekdayMask : 0,
            knowledgeNodeID: knowledgeNodeID
        )
        modelContext.insert(task)
        do {
            try modelContext.save()
        } catch {
            statusMessage = "保存任务失败：\(error.localizedDescription)"
            return nil
        }
        dailyTasks.append(task)
        dailyTaskByID[task.id] = task
        return task
    }

    func updateDailyTask(
        _ task: DailyTask,
        title: String,
        noteText: String?,
        dueDate: Date?,
        weekdayMask: Int,
        knowledgeNodeID: UUID?,
        calendar: Calendar = .current
    ) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            statusMessage = "标题不能为空"
            return
        }
        task.title = trimmedTitle
        task.noteText = normalizedNote(noteText)
        task.dueDate = task.isHabit ? nil : dueDate.map { calendar.startOfDay(for: $0) }
        task.weekdayMask = task.isHabit ? weekdayMask : 0
        task.knowledgeNodeID = knowledgeNodeID
        do {
            try modelContext.save()
        } catch {
            statusMessage = "更新任务失败：\(error.localizedDescription)"
        }
        touchDailyLessonObservation()
    }

    /// 待办完成/撤销完成；完成时间是即时申报，不追溯历史日期。
    func toggleTodo(_ task: DailyTask, now: Date = .now) {
        guard !task.isArchived, task.kind == .todo else { return }
        if task.completedAt == nil {
            task.completedAt = now
        } else {
            task.completedAt = nil
        }
        do {
            try modelContext.save()
        } catch {
            statusMessage = "更新任务失败：\(error.localizedDescription)"
        }
        touchDailyLessonObservation()
    }

    /// 习惯打卡：仅允许当天，且同一自然日只计一次（不允许补打卡）。
    func completeHabit(_ task: DailyTask, on day: Date = .now, now: Date = .now, calendar: Calendar = .current) {
        guard !task.isArchived, task.isHabit else { return }
        let logDay = calendar.startOfDay(for: day)
        guard logDay == calendar.startOfDay(for: now) else {
            statusMessage = "日课只认当日完成，不能补打卡"
            return
        }
        guard habitLog(for: task, day: logDay) == nil else { return }
        let log = DailyTaskLog(taskID: task.id, day: logDay, completedAt: now)
        modelContext.insert(log)
        do {
            try modelContext.save()
        } catch {
            statusMessage = "打卡失败：\(error.localizedDescription)"
            return
        }
        dailyTaskLogs.insert(log, at: 0)
        dailyTaskLogsByTaskID[task.id, default: []].append(log)
        dailyTaskLogsByTaskID[task.id]?.sort { $0.day < $1.day }
        touchDailyLessonObservation()
    }

    /// 撤销当天打卡（仅当天可撤）。
    func removeHabitLog(for task: DailyTask, on day: Date = .now, calendar: Calendar = .current) {
        guard task.isHabit else { return }
        let logDay = calendar.startOfDay(for: day)
        guard let log = habitLog(for: task, day: logDay) else { return }
        modelContext.delete(log)
        do {
            try modelContext.save()
        } catch {
            statusMessage = "撤销打卡失败：\(error.localizedDescription)"
            return
        }
        dailyTaskLogs.removeAll { $0.id == log.id }
        dailyTaskLogsByTaskID[task.id]?.removeAll { $0.id == log.id }
        touchDailyLessonObservation()
    }

    /// 打卡圆环的单点入口：今天已完成则撤销，否则打卡。
    func toggleHabit(_ task: DailyTask, now: Date = .now, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        if habitLog(for: task, day: today) != nil {
            removeHabitLog(for: task, on: today, calendar: calendar)
        } else {
            completeHabit(task, on: today, now: now, calendar: calendar)
        }
    }

    func archiveDailyTask(_ task: DailyTask, now: Date = .now) {
        task.isArchived = true
        task.archivedAt = now
        try? modelContext.save()
        touchDailyLessonObservation()
    }

    func unarchiveDailyTask(_ task: DailyTask) {
        task.isArchived = false
        task.archivedAt = nil
        try? modelContext.save()
        touchDailyLessonObservation()
    }

    /// 删除任务并级联清理打卡日志；历史热力图随日志一同消失。
    func deleteDailyTask(_ task: DailyTask) {
        for log in dailyTaskLogsByTaskID[task.id] ?? [] {
            modelContext.delete(log)
        }
        modelContext.delete(task)
        do {
            try modelContext.save()
        } catch {
            statusMessage = "删除任务失败：\(error.localizedDescription)"
            return
        }
        dailyTaskLogs.removeAll { $0.taskID == task.id }
        dailyTaskLogsByTaskID[task.id] = nil
        dailyTaskByID[task.id] = nil
        dailyTasks.removeAll { $0.id == task.id }
    }

    /// 打卡/勾选只改动模型字段；显式触碰数组让依赖 AppState 派生值的区块同步刷新。
    func touchDailyLessonObservation() {
        dailyTasks = dailyTasks
        dailyTaskLogs = dailyTaskLogs
        dailyLessonRevision += 1
    }

    /// 推迟待办：无截止日时从今天起算。
    func postponeTodo(
        _ task: DailyTask,
        byDays days: Int = 1,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        guard !task.isArchived, !task.isHabit else { return }
        let base = task.dueDate ?? calendar.startOfDay(for: now)
        task.dueDate = calendar.date(byAdding: .day, value: days, to: base)
        do {
            try modelContext.save()
        } catch {
            statusMessage = "推迟失败：\(error.localizedDescription)"
            return
        }
        touchDailyLessonObservation()
    }

    // MARK: - 派生查询

    /// 今日待办：未完成（逾期/今天/不限日）在前，今日已完成在后。
    func todayTodoGroups(now: Date = .now, calendar: Calendar = .current) -> (open: [DailyTask], completed: [DailyTask]) {
        let today = calendar.startOfDay(for: now)
        let active = dailyTasks.filter { !$0.isArchived && !$0.isHabit }
        var open = active.filter { task in
            guard task.completedAt == nil else { return false }
            guard let dueDate = task.dueDate else { return true }
            return calendar.startOfDay(for: dueDate) <= today
        }
        open.sort { lhs, rhs in
            let lhsBucket = DailyLessonAnalytics.dueBucket(for: lhs.dueDate, now: now, calendar: calendar)
            let rhsBucket = DailyLessonAnalytics.dueBucket(for: rhs.dueDate, now: now, calendar: calendar)
            if lhsBucket != rhsBucket { return dueSortOrder(lhsBucket) < dueSortOrder(rhsBucket) }
            return lhs.createdAt < rhs.createdAt
        }
        let completed = active
            .filter { task in
                guard let completedAt = task.completedAt else { return false }
                return calendar.isDate(completedAt, inSameDayAs: today)
            }
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
        return (open, completed)
    }

    /// 即将到来的待办（明天及以后），按截止日升序。
    func upcomingTodos(now: Date = .now, calendar: Calendar = .current) -> [DailyTask] {
        let today = calendar.startOfDay(for: now)
        return dailyTasks
            .filter { task in
                guard !task.isArchived, !task.isHabit, task.completedAt == nil else { return false }
                guard let dueDate = task.dueDate else { return false }
                return calendar.startOfDay(for: dueDate) > today
            }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    /// 今天被调度（或待补齐语境外不存在）的习惯，按创建时间排序。
    func todayHabits(now: Date = .now, calendar: Calendar = .current) -> [DailyTask] {
        dailyTasks
            .filter { task in
                !task.isArchived
                    && task.isHabit
                    && DailyLessonAnalytics.isWeekdayMaskScheduled(task.weekdayMask, on: now, calendar: calendar)
            }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// 未被今日调度仍显式的习惯（供查看全量）。
    var activeHabits: [DailyTask] {
        dailyTasks.filter { !$0.isArchived && $0.isHabit }
    }

    func isHabitCompletedToday(_ task: DailyTask, now: Date = .now, calendar: Calendar = .current) -> Bool {
        habitLog(for: task, day: calendar.startOfDay(for: now)) != nil
    }

    func habitStreak(for task: DailyTask, now: Date = .now, calendar: Calendar = .current) -> Int {
        DailyLessonAnalytics.habitStreak(
            completedDays: habitCompletedDays(for: task, calendar: calendar),
            weekdayMask: task.weekdayMask,
            now: now,
            calendar: calendar
        )
    }

    func longestHabitStreak(for task: DailyTask, now: Date = .now, calendar: Calendar = .current) -> Int {
        DailyLessonAnalytics.longestHabitStreak(
            completedDays: habitCompletedDays(for: task, calendar: calendar),
            weekdayMask: task.weekdayMask,
            now: now,
            calendar: calendar
        )
    }

    /// 今日全部完成数 = 今日完成待办 + 今日习惯打卡，用于菜单栏与热力图当日格。
    func todayDailyCompletionCount(now: Date = .now, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        let todos = dailyTasks.count { task in
            guard !task.isHabit, let completedAt = task.completedAt else { return false }
            return calendar.startOfDay(for: completedAt) == today
        }
        let habits = dailyTaskLogs.count { calendar.startOfDay(for: $0.day) == today }
        return todos + habits
    }

    /// 今日日课总量（待办未完成 + 今日计划习惯），用于"x/y"进度。
    func todayDailyTaskTotals(now: Date = .now, calendar: Calendar = .current) -> (done: Int, total: Int) {
        let (open, completed) = todayTodoGroups(now: now, calendar: calendar)
        let scheduledHabits = todayHabits(now: now, calendar: calendar)
        let finishedHabits = scheduledHabits.count { isHabitCompletedToday($0, now: now, calendar: calendar) }
        return (completed.count + finishedHabits, open.count + completed.count + scheduledHabits.count)
    }

    /// 热力图数据：日课完成数与真实学习活动数共同形成强度；暖金描边仍标识真实活动。
    func dailyLessonHeatmap(
        weekCount: Int = 26,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DailyLessonHeatmapData {
        let learningActivityData = learningActivityData(since: now, weekCount: weekCount, calendar: calendar)
        return DailyLessonAnalytics.heatmap(
            weekCount: weekCount,
            completionCountsByDay: completionCountsByDay(calendar: calendar),
            learningActivityCountsByDay: learningActivityData.counts,
            learningActivitiesByDay: learningActivityData.details,
            now: now,
            calendar: calendar
        )
    }

    func knowledgeNode(for task: DailyTask) -> KnowledgeNode? {
        guard let knowledgeNodeID = task.knowledgeNodeID else { return nil }
        return nodeByID[knowledgeNodeID]
    }

    /// 跨零点刷新；由 AutomationTick 与页面 onAppear 调用，仅在变更时赋值以减少重绘。
    func refreshDailyLessonDay(now: Date = .now, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: now)
        if dailyLessonDay != day {
            dailyLessonDay = day
        }
    }

    // MARK: - 私有辅助

    private func habitLog(for task: DailyTask, day: Date, calendar: Calendar = .current) -> DailyTaskLog? {
        let normalizedDay = calendar.startOfDay(for: day)
        return (dailyTaskLogsByTaskID[task.id] ?? []).first { calendar.startOfDay(for: $0.day) == normalizedDay }
    }

    private func habitCompletedDays(for task: DailyTask, calendar: Calendar) -> Set<Date> {
        Set((dailyTaskLogsByTaskID[task.id] ?? []).map { calendar.startOfDay(for: $0.day) })
    }

    private func completionCountsByDay(calendar: Calendar) -> [Date: Int] {
        var counts: [Date: Int] = [:]
        for task in dailyTasks where !task.isHabit {
            guard let completedAt = task.completedAt else { continue }
            counts[calendar.startOfDay(for: completedAt), default: 0] += 1
        }
        for log in dailyTaskLogs {
            counts[calendar.startOfDay(for: log.day), default: 0] += 1
        }
        return counts
    }

    /// 真实学习活动：按自然日聚合，供热力图同时表达活动强度与是否存在真实采集。
    private func learningActivityData(
        since now: Date,
        weekCount: Int,
        calendar: Calendar
    ) -> (counts: [Date: Int], details: [Date: [DailyLessonHeatmapActivity]]) {
        let rangeStart = calendar.date(byAdding: .day, value: -7 * weekCount, to: calendar.startOfDay(for: now)) ?? now
        do {
            let events = try modelContext.fetch(
                FetchDescriptor<ActivityEvent>(
                    predicate: #Predicate<ActivityEvent> { $0.timestamp >= rangeStart }
                )
            )
            var counts: [Date: Int] = [:]
            var details: [Date: [DailyLessonHeatmapActivity]] = [:]
            for event in events {
                let day = calendar.startOfDay(for: event.timestamp)
                counts[day, default: 0] += 1
                if details[day, default: []].count < 3 {
                    details[day, default: []].append(
                        DailyLessonHeatmapActivity(id: event.id, title: event.title, summary: event.summary)
                    )
                }
            }
            return (counts, details)
        } catch {
            AppLogger.app.error("Failed to collect learning activity counts: \(error.localizedDescription, privacy: .public)")
            return ([:], [:])
        }
    }

    private func dueSortOrder(_ bucket: DailyTaskDueBucket) -> Int {
        switch bucket {
        case .overdue: 0
        case .today: 1
        case .undated: 2
        case .tomorrow: 3
        case .upcoming: 4
        }
    }

    private func normalizedNote(_ noteText: String?) -> String? {
        guard let noteText else { return nil }
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
