import SwiftUI

struct MenuBarNavigationItem: Identifiable {
    enum Action {
        case section(NavigationSection)
        case review
        case taxonomyReview
    }

    let id: String
    let title: String
    let icon: String
    let primaryMetric: String
    let action: Action
}
