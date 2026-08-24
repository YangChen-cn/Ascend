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
        AppPageScaffold {
            ResponsivePageHeader {
                PageHeaderView(
                    AscendTheme.isXuanqing ? "仙门试炼 · 问道破境" : "修炼挑战",
                    subtitle: "以真实工程实践破境，完成后经由学习实据验证，方可正式结算知验。",
                    systemImage: "flag.checkered"
                )

            } actions: {
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

            AdaptivePageColumns {
                VStack(alignment: .leading, spacing: AscendTheme.Spacing.section) {
                    if appState.challenges.isEmpty {
                        ChallengeEmptyStateView()
                            .sectionSurface(.grouped)
                        ChallengeCodexCard()
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 320, maximum: 540), spacing: 14)], spacing: 14) {
                            ForEach(appState.challenges) { challenge in
                                ChallengeCardView(challenge: challenge, action: startChallenge)
                            }
                        }

                        // 挑战较少时展示破境演武心诀卡，充实页面
                        if appState.challenges.count <= 2 {
                            ChallengeCodexCard()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } supplementary: {
                ChallengeRulesView()
                    .sectionSurface(.grouped)
            }

            if appState.challenges.isEmpty {
                ChallengeUnlockPathView()
            }
        }
    }

    private func startChallenge(_ challenge: Challenge) {
        if challenge.status != "completed" && challenge.status != "in_progress" {
            appState.updateChallengeStatus(challenge, status: "in_progress")
        }
    }
}
