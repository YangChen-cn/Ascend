import Foundation

struct ExportedDailyTask: Codable, Sendable {
    let id: UUID
    let kindRawValue: String
    let title: String
    let noteText: String?
    let createdAt: Date
    let dueDate: Date?
    let weekdayMask: Int
    let knowledgeNodeID: UUID?
    let completedAt: Date?
    let isArchived: Bool
    let archivedAt: Date?
}

struct ExportedDailyTaskLog: Codable, Sendable {
    let id: UUID
    let taskID: UUID
    let day: Date
    let completedAt: Date
}

struct ExportedFocusSession: Codable, Sendable {
    let id: UUID
    let taskID: UUID?
    let phaseRawValue: String
    let plannedSeconds: Int
    let startedAt: Date
    let endedAt: Date?
    let statusRawValue: String
    let pausedSeconds: Int
}
