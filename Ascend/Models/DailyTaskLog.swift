import Foundation
import SwiftData

/// 习惯的每日打卡记录；(taskID, day) 的唯一性由 AppState 完成守卫保证。
@Model
final class DailyTaskLog {
    @Attribute(.unique) var id: UUID
    var taskID: UUID
    /// 打卡所属自然日（startOfDay）。
    var day: Date
    var completedAt: Date

    init(id: UUID = UUID(), taskID: UUID, day: Date, completedAt: Date = .now) {
        self.id = id
        self.taskID = taskID
        self.day = day
        self.completedAt = completedAt
    }
}
