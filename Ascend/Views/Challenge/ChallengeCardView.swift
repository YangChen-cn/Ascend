import SwiftUI

struct ChallengeCardView: View {
    let challenge: Challenge
    let action: (Challenge) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title)
                        .font(.system(.title3, design: .serif))
                        .bold()

                    HStack(spacing: 8) {
                        Label("\(challenge.estimatedMinutes) 刻钟", systemImage: "hourglass")
                        Text("·")
                        Label("\(challenge.knowledgeNodeIDs.count) 处知窍", systemImage: "point.3.filled.connected.trianglepath.dotted")
                    }
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(.secondary)
                }

                Spacer()

                CelestialBadge(
                    title: "+\(challenge.rewardXP) 挑战 XP",
                    systemImage: "flame.fill",
                    style: .gold
                )
            }

            Text(challenge.challengeDescription)
                .font(.system(.callout, design: .serif))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .overlay {
                    AscendTheme.gold.opacity(0.15)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text("试炼要求")
                    .font(.system(.caption2, design: .serif))
                    .foregroundStyle(.secondary)

                ForEach(challenge.requirements.prefix(4), id: \.self) { requirement in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "rhombus.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(AscendTheme.gold)
                            .padding(.top, 5)
                        Text(requirement)
                            .font(.system(.callout, design: .serif))
                    }
                }
            }

            Spacer(minLength: 4)

            HStack {
                if challenge.status == "completed" {
                    CelestialBadge(
                        title: "试炼圆满·已获修为",
                        systemImage: "checkmark.seal.fill",
                        style: .jade
                    )
                } else if challenge.status == "in_progress" {
                    CelestialBadge(
                        title: "进行中 · 等待实据",
                        systemImage: "flame",
                        style: .cinnabar
                    )
                } else {
                    Button("接取试炼", systemImage: "sparkles", action: { action(challenge) })
                        .buttonStyle(.borderedProminent)
                        .tint(AscendTheme.gold)
                }
            }
        }
        .panelCard(highlighted: challenge.status == "in_progress")
        .accessibilityHint(challenge.status == "in_progress" ? "满足结构化条件并产生已验证实据后自动完成" : "")
    }
}
