import Foundation
import SwiftData

enum DailyTaskKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case todo
    case habit

    var id: Self { self }

    var title: String {
        switch self {
        case .todo: "待办"
        case .habit: "习惯"
        }
    }
}

@Model
final class DailyTask {
    /// bit0 = 周日 … bit6 = 周六；全 0 表示每天重复。
    static let allWeekdayMask = (1 << 7) - 1

    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var title: String
    var noteText: String?
    var createdAt: Date
    /// 待办的目标日（startOfDay）；nil 表示不限日期，仅出现在今日清单。
    var dueDate: Date?
    /// 习惯的重复星期掩码；仅 kind == .habit 时有意义。
    var weekdayMask: Int
    var knowledgeNodeID: UUID?
    /// 待办的一次性完成时间；习惯的完成记录在 DailyTaskLog。
    var completedAt: Date?
    var isArchived: Bool
    var archivedAt: Date?

    init(
        id: UUID = UUID(),
        kind: DailyTaskKind,
        title: String,
        noteText: String? = nil,
        createdAt: Date = .now,
        dueDate: Date? = nil,
        weekdayMask: Int = 0,
        knowledgeNodeID: UUID? = nil,
        completedAt: Date? = nil,
        isArchived: Bool = false,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.kindRawValue = kind.rawValue
        self.title = title
        self.noteText = noteText
        self.createdAt = createdAt
        self.dueDate = dueDate
        self.weekdayMask = weekdayMask
        self.knowledgeNodeID = knowledgeNodeID
        self.completedAt = completedAt
        self.isArchived = isArchived
        self.archivedAt = archivedAt
    }

    var kind: DailyTaskKind {
        DailyTaskKind(rawValue: kindRawValue) ?? .todo
    }

    var isHabit: Bool { kind == .habit }
}
