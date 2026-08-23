import Foundation

struct MasteryVector: Codable, Equatable, Sendable {
    var exposure: Double
    var understanding: Double
    var practice: Double
    var retention: Double
    var autonomy: Double

    static let zero = Self(exposure: 0, understanding: 0, practice: 0, retention: 0, autonomy: 0)

    var composite: Double {
        exposure * 0.10
            + understanding * 0.25
            + practice * 0.25
            + retention * 0.20
            + autonomy * 0.20
    }

    func clamped() -> Self {
        Self(
            exposure: exposure.clamped(to: 0...100),
            understanding: understanding.clamped(to: 0...100),
            practice: practice.clamped(to: 0...100),
            retention: retention.clamped(to: 0...100),
            autonomy: autonomy.clamped(to: 0...100)
        )
    }
}
