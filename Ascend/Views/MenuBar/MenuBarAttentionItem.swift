import SwiftUI

struct MenuBarAttentionItem: Identifiable {
    enum Destination {
        case review
        case knowledge(UUID)
        case taxonomyReview
        case challenges
        case today
    }

    let id: String
    let priority: Int
    let icon: String
    let tint: Color
    let title: String
    let status: String
    let destination: Destination
}
