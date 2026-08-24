import Foundation

enum MasteryMeasurementStatus: String, Codable, Sendable {
    case unmeasured
    case initial
    case supported
    case calibrated

    var title: String {
        switch self {
        case .unmeasured: "未测量"
        case .initial: "初始估计"
        case .supported: "已有表现支持"
        case .calibrated: "已具备校准样本"
        }
    }
}
