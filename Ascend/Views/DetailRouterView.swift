import SwiftUI

struct DetailRouterView: View {
    let section: NavigationSection

    var body: some View {
        switch section {
        case .today:
            TodayDashboardView()
        case .review:
            ReviewQueueView()
        case .knowledge:
            KnowledgeGraphScreen()
        case .abilities:
            AbilityMapView()
        case .challenges:
            ChallengesView()
        case .evidence:
            EvidenceFeedView()
        }
    }
}
