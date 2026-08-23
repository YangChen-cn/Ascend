import Foundation

enum DomainRealm: Int, CaseIterable, Codable, Sendable {
    case unstarted
    case apprentice
    case entry
    case advancing
    case refining
    case connected
    case transformed

    var title: String {
        switch self {
        case .unstarted: "尚未入境"
        case .apprentice: "初窥"
        case .entry: "入门"
        case .advancing: "通晓"
        case .refining: "融会"
        case .connected: "化用"
        case .transformed: "通达"
        }
    }

    var minimumScore: Double {
        switch self {
        case .unstarted, .apprentice: 0
        case .entry: 20
        case .advancing: 40
        case .refining: 60
        case .connected: 80
        case .transformed: 90
        }
    }

    var minimumXP: Int {
        switch self {
        case .unstarted: 0
        case .apprentice: 1
        case .entry: 300
        case .advancing: 1_000
        case .refining: 3_000
        case .connected: 7_000
        case .transformed: 15_000
        }
    }

    var next: Self? { Self(rawValue: rawValue + 1) }

    static func resolve(score: Double, xp: Int) -> Self {
        allCases.reversed().first { score >= $0.minimumScore && xp >= $0.minimumXP } ?? .unstarted
    }
}
