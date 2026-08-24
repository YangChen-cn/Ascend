import SwiftUI

struct GrowthRailView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForgettingListView()
                .sectionSurface(.grouped)

            RealmProgressView()
                .sectionSurface(.grouped)

            ChallengeCalloutView()
                .sectionSurface(.grouped)

            SourceHealthRailCard()
                .sectionSurface(.grouped)

            if appState.knowledgeNodes.isEmpty || appState.sources.isEmpty {
                OnboardingGuideCard()
                    .sectionSurface(.emphasized)
            }
        }
        .frame(maxHeight: .infinity)
    }
}
