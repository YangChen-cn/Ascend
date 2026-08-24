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
                    .font(.caption)
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
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
                .overlay {
                    AscendTheme.gold.opacity(0.15)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text("试炼要求")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ForEach(challenge.requirements.prefix(4), id: \.self) { requirement in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "rhombus.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(AscendTheme.gold)
                            .padding(.top, 5)
                        Text(requirement)
                            .font(.callout)
                    }
                }
            }

            Spacer(minLength: 4)

            HStack {
                if challenge.status == "completed" {
                    HStack(spacing: 8) {
                        CelestialBadge(
                            title: "试炼圆满·已获修为",
                            systemImage: "checkmark.seal.fill",
                            style: .jade
                        )
                        if AscendTheme.isXuanqing {
                            ClassicalSealMark(text: "功成", shape: .square, style: .jade, carving: .intaglio, size: 22)
                        }
                    }
                } else if challenge.status == "in_progress" {
                    HStack(spacing: 8) {
                        CelestialBadge(
                            title: "进行中 · 等待实据",
                            systemImage: "flame",
                            style: .cinnabar
                        )
                        if AscendTheme.isXuanqing {
                            ClassicalSealMark(text: "问道", shape: .square, style: .cinnabar, carving: .intaglio, size: 22)
                        }
                    }
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
