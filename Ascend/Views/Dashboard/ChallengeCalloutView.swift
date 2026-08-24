import SwiftUI

struct ChallengeCalloutView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "flag.checkered.2.crossed")
                        .foregroundStyle(AscendTheme.gold)
                    Text("仙门试炼 · 问道机缘")
                        .font(.system(.headline, design: .serif))
                        .bold()
                }
                Spacer()
                if let challenge = appState.challenges.first {
                    CelestialBadge(
                        title: "+\(challenge.rewardXP) XP",
                        style: .gold
                    )
                }
            }

            if let challenge = appState.challenges.first {
                VStack(alignment: .leading, spacing: 6) {
                    Text(challenge.title)
                        .font(.body)
                        .bold()

                    HStack(spacing: 6) {
                        Label("\(challenge.estimatedMinutes) 刻钟", systemImage: "hourglass")
                        Text("·")
                        Label("\(challenge.knowledgeNodeIDs.count) 知窍", systemImage: "point.3.filled.connected.trianglepath.dotted")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Button(action: startChallenge) {
                    HStack {
                        Spacer()
                        Label("前往试炼洞天", systemImage: "sparkles")
                            .font(.callout)
                            .bold()
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AscendTheme.gold)
                .controlSize(.regular)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "flag.2.crossed")
                        .font(.title3)
                        .foregroundStyle(AscendTheme.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("静候机缘 · 暂无试炼")
                            .font(.subheadline)
                            .bold()
                        Text("待学习活动分析完成后，系统将自动推演适合破境的研习试炼。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func startChallenge() {
        appState.selectedSection = .challenges
    }
}
