import SwiftUI

struct GrowthRailView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForgettingListView()
                .panelCard()

            RealmProgressView()
                .panelCard()

            ChallengeCalloutView()
                .panelCard()

            if appState.knowledgeNodes.isEmpty || appState.sources.isEmpty {
                OnboardingGuideCard()
                    .panelCard(highlighted: true)
            }
        }
    }
}
