import SwiftUI

struct ChallengeCardView: View {
    @Environment(AppState.self) private var appState
    let challenge: Challenge
    let action: (Challenge) -> Void

    @State private var showsEvidenceSubmission = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

                ForEach(appState.challengeRequirementDescriptions(for: challenge).prefix(4), id: \.self) { requirement in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "rhombus.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(AscendTheme.gold)
                            .padding(.top, 5)
                        Text(requirement)
                            .font(.callout)
                    }
                }
                if challenge.knowledgeNodeIDs.count > 1 {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "rhombus.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(AscendTheme.gold)
                            .padding(.top, 5)
                        Text("\(challenge.knowledgeNodeIDs.count) 处知窍均需在接取后形成直接实据")
                            .font(.callout)
                    }
                }
            }

            HStack(alignment: .bottom) {
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
                    HStack {
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 6) {
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
                            HStack(spacing: 8) {
                                ChallengeAssessmentLaunchButton(challenge: challenge)
                                Button("提交实作证据", systemImage: "tray.and.arrow.up") {
                                    showsEvidenceSubmission = true
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .help("选择接取后采集的 Git 提交，或本地文件作为实作证据来源；不上传源码，也不进行作者检测")
                            }
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
        .sheet(isPresented: $showsEvidenceSubmission) {
            ChallengeEvidenceSubmissionView(challenge: challenge)
        }
        .accessibilityHint(challenge.status == "in_progress" ? "满足结构化条件并产生已验证实据后自动完成" : "")
    }
}
