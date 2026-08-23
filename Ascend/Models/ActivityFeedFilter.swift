import Foundation

enum ActivityFeedFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "全部"
    case pending = "待分析"
    case processed = "已分析"

    var id: Self { self }
}
