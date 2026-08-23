import SwiftUI

struct MenuBarNavigationItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let section: NavigationSection
    let primaryMetric: String
    let secondaryMetric: String
    let tint: Color
    let isReviewAction: Bool
}
