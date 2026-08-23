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
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(AscendTheme.isXuanqing ? "仙门试炼 · 问道破境" : "修炼挑战")
                                .font(.system(.largeTitle, design: AscendTheme.titleDesign))
                                .bold()
                            Text("以真实工程实践破境，完成后经由学习实据验证，方可正式结算知验。")
                                .font(.system(.callout, design: AscendTheme.titleDesign))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 8) {
                            CelestialBadge(
                                title: "待修试炼",
                                subtitle: "\(activeCount)",
                                systemImage: "flag.fill",
                                style: .cinnabar
                            )
                            CelestialBadge(
                                title: "已证功成",
                                subtitle: "\(completedCount)",
                                systemImage: "checkmark.seal.fill",
                                style: .jade
                            )
                            CelestialBadge(
                                title: "可获挑战经验",
                                subtitle: "\(availableXP.formatted()) XP",
                                systemImage: "flame.fill",
                                style: .gold
                            )
                        }
                    }
                    .panelCard()

                    if appState.challenges.isEmpty {
                        HStack(alignment: .top, spacing: 18) {
                            ChallengeEmptyStateView()
                                .panelCard()
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ChallengeRulesView()
                                .panelCard()
                                .frame(width: 360)
                        }
                        ChallengeUnlockPathView()
                    } else {
                        HStack(alignment: .top, spacing: 18) {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16)], spacing: 16) {
                                ForEach(appState.challenges) { challenge in
                                    ChallengeCardView(challenge: challenge, action: startChallenge)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            ChallengeRulesView()
                                .panelCard()
                                .frame(width: 360)
                        }
                    }
                }
                .frame(maxWidth: 1_280, alignment: .leading)
                .padding(28)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func startChallenge(_ challenge: Challenge) {
        if challenge.status != "completed" && challenge.status != "in_progress" {
            appState.updateChallengeStatus(challenge, status: "in_progress")
        }
    }
}
