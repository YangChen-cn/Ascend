import Foundation

struct DashboardMetric: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let previous: Int
    let current: Int
}
