import SwiftUI

struct GrowthRailView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            ForgettingListView()
            Divider()
            RealmProgressView()
            Divider()
            ChallengeCalloutView()
        }
    }
}
