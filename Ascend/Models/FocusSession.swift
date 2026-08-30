import Foundation
import SwiftData

enum FocusPhase: String, Codable, Sendable, CaseIterable {
    case focus
    case rest

    var title: String {
        switch self {
        case .focus: "专注"
        case .rest: "休息"
        }
    }
}

enum FocusSessionStatus: String, Codable, Sendable {
    case active
    case completed
    case interrupted
}

/// 一段专注（焚香）或休息计时；关窗与重启不丢，重启时由 AppState 结算过期会话。
@Model
final class FocusSession {
    @Attribute(.unique) var id: UUID
    var taskID: UUID?
    var phaseRawValue: String
    var plannedSeconds: Int
    var startedAt: Date
    var endedAt: Date?
    var statusRawValue: String
    var pausedSeconds: Int
    var pausedAt: Date?

    init(
        id: UUID = UUID(),
        taskID: UUID? = nil,
        phase: FocusPhase,
        plannedSeconds: Int,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        status: FocusSessionStatus = .active,
        pausedSeconds: Int = 0,
        pausedAt: Date? = nil
    ) {
        self.id = id
        self.taskID = taskID
        self.phaseRawValue = phase.rawValue
        self.plannedSeconds = plannedSeconds
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.statusRawValue = status.rawValue
        self.pausedSeconds = pausedSeconds
        self.pausedAt = pausedAt
    }

    var phase: FocusPhase {
        FocusPhase(rawValue: phaseRawValue) ?? .focus
    }

    var status: FocusSessionStatus {
        FocusSessionStatus(rawValue: statusRawValue) ?? .active
    }
}
