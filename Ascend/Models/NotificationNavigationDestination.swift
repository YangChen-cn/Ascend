import Foundation

enum NotificationNavigationDestination: Sendable, Equatable {
    case assessment
    case today
    case review
    case challenges
    case notificationSettings
    case knowledge(UUID)

    private enum Key {
        static let destination = "ascend.notification.destination"
        static let knowledgeNodeID = "ascend.notification.knowledgeNodeID"
    }

    private enum Value {
        static let assessment = "assessment"
        static let today = "today"
        static let review = "review"
        static let challenges = "challenges"
        static let notificationSettings = "notificationSettings"
        static let knowledge = "knowledge"
    }

    var userInfo: [AnyHashable: Any] {
        switch self {
        case .assessment:
            [Key.destination: Value.assessment]
        case .today:
            [Key.destination: Value.today]
        case .review:
            [Key.destination: Value.review]
        case .challenges:
            [Key.destination: Value.challenges]
        case .notificationSettings:
            [Key.destination: Value.notificationSettings]
        case .knowledge(let nodeID):
            [Key.destination: Value.knowledge, Key.knowledgeNodeID: nodeID.uuidString]
        }
    }

    init?(userInfo: [AnyHashable: Any]) {
        guard let value = userInfo[Key.destination] as? String else { return nil }
        switch value {
        case Value.assessment:
            self = .assessment
        case Value.today:
            self = .today
        case Value.review:
            self = .review
        case Value.challenges:
            self = .challenges
        case Value.notificationSettings:
            self = .notificationSettings
        case Value.knowledge:
            guard let rawID = userInfo[Key.knowledgeNodeID] as? String,
                  let nodeID = UUID(uuidString: rawID) else { return nil }
            self = .knowledge(nodeID)
        default:
            return nil
        }
    }
}
