import SwiftUI

struct ChallengesView: View {
    @Environment(AppState.self) private var appState

    private var activeCount: Int {
        appState.challenges.count { $0.status != "completed" }
    }

    private var completedCount: Int {
        appState.challenges.count { $0.status == "completed" }
    }

    private var availableXP: Int {
        appState.challenges.filter { $0.status != "completed" }.reduce(0) { $0 + $1.rewardXP }
    }

    var body: some View {
        ZStack {
            FeaturePageBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    PageHeaderView(
                        "修炼挑战",
                        subtitle: "以真实实践破境；完成后仍需学习证据验证，方可结算知验。",
                        systemImage: "flag.checkered"
                    )

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
                        MetricTileView(title: "待修挑战", value: activeCount.formatted(), systemImage: "flag", detail: "已解锁且尚未验证")
                        MetricTileView(title: "已证挑战", value: completedCount.formatted(), systemImage: "checkmark.seal", detail: "由后续证据完成结算")
                        MetricTileView(title: "可得知验", value: "\(availableXP.formatted()) XP", systemImage: "seal", detail: "手动勾选不会直接获得")
                    }

                    if appState.challenges.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 360), spacing: 16)], spacing: 16) {
                            ChallengeEmptyStateView()
                            ChallengeRulesView()
                        }
                        ChallengeUnlockPathView()
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 16)], spacing: 16) {
                            ForEach(appState.challenges) { challenge in
                                ChallengeCardView(challenge: challenge, action: startChallenge)
                            }
                        }
                        ChallengeRulesView()
                    }
                }
                .frame(maxWidth: 1_280, alignment: .leading)
                .padding(28)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func startChallenge(_ challenge: Challenge) {
        appState.statusMessage = "已将“\(challenge.title)”加入当前修炼目标"
    }
}
