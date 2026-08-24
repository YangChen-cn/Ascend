import Foundation

enum MasteryMeasurementStatus: String, Codable, Sendable {
    case unmeasured
    case initial
    case supported
    case calibrated

    var title: String {
        switch self {
        case .unmeasured: "待印证"
        case .initial: "初入印证"
        case .supported: "基础印证"
        case .calibrated: "深度印证"
        }
    }
}
