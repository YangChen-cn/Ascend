import Foundation

enum NavigationSection: String, CaseIterable, Identifiable, Codable, Sendable {
    case today
    case review
    case knowledge
    case abilities
    case challenges
    case evidence

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "今日"
        case .review: "到期复习"
        case .knowledge: "知识图谱"
        case .abilities: "能力地图"
        case .challenges: "修炼挑战"
        case .evidence: "资料流"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "house"
        case .review: "clock.arrow.circlepath"
        case .knowledge: "point.3.connected.trianglepath.dotted"
        case .abilities: "map"
        case .challenges: "flag.checkered"
        case .evidence: "list.bullet.rectangle"
        }
    }
}
