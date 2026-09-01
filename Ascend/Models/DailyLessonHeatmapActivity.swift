import Foundation

/// 热力图详情中展示的有限活动摘要；不携带原始内容或审计片段。
struct DailyLessonHeatmapActivity: Equatable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let summary: String
}
