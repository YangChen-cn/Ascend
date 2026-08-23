import Foundation

struct TrajectoryPoint: Identifiable, Sendable {
    let id = UUID()
    let day: Int
    let score: Double
    let label: String?
}
