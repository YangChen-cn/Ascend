import SwiftUI

struct ChallengeCardView: View {
    @Environment(AppState.self) private var appState
    let challenge: Challenge
    let action: (Challenge) -> Void

    @State private var showsEvidenceSubmission = false
    @State private var showsAbandonConfirmation = false

    private var knowledgeCheckRewardXP: Int {
        max(1, Int((Double(challenge.rewardXP) * AppConstants.challengeKnowledgeCheckRewardRatio).rounded(.down)))
    }

    private var challengeRequirement: ChallengeRequirement {
        appState.challengeRequirement(for: challenge) ?? ChallengeRequirement()
    }

    private var isProductionChallenge: Bool {
        challengeRequirement.minimumEvidenceKind.challengeRank >= EvidenceKind.project.challengeRank
    }

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
                    title: challenge.status == "completed"
                        ? "+\(appState.challengeEarnedXP(for: challenge)) 挑战 XP"
                        : "答题 +\(knowledgeCheckRewardXP) · 实作 +\(challenge.rewardXP) XP",
                    systemImage: "flame.fill",
                    style: .gold
                )
            }

            Text(challenge.challengeDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if isProductionChallenge {
                HStack {
                    Spacer()
                    Button("复制实作题目", systemImage: "doc.on.doc", action: copyChallengePrompt)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("复制任务描述、目标知识点、验收要求与提交说明")
                }
            }

            Divider()
                .overlay {
                    AscendTheme.gold.opacity(0.15)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text("两种完成方式")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label("知识验证：完成选择题，获得 \(knowledgeCheckRewardXP) 挑战 XP", systemImage: "checkmark.seal")
                    .font(.callout)
                Label("实作核验：提交代码或文件并通过 AI 复核，获得完整 \(challenge.rewardXP) 挑战 XP", systemImage: "hammer")
                    .font(.callout)

                Text("实作路径要求")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

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
                                .help("选择最近三天采集的 Git 提交，或本地文件作为候选实作来源；由 AI 复核后才会形成通过证据")
                                Button("放弃", role: .destructive) {
                                    showsAbandonConfirmation = true
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                } else if challenge.status == "abandoned" {
                    HStack {
                        CelestialBadge(title: "已放弃", systemImage: "xmark.seal", style: .cinnabar)
                        Spacer()
                        Button("重新接取", systemImage: "arrow.counterclockwise", action: { action(challenge) })
                            .buttonStyle(.bordered)
                            .controlSize(.small)
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
        .confirmationDialog("放弃这项挑战？", isPresented: $showsAbandonConfirmation, titleVisibility: .visible) {
            Button("放弃挑战", role: .destructive) {
                appState.abandonChallenge(challenge)
            }
        } message: {
            Text("不会删除已有学习记录或 XP；之后可重新接取。")
        }
        .accessibilityHint(challenge.status == "in_progress" ? "满足结构化条件并产生已验证实据后自动完成" : "")
    }

    private func copyChallengePrompt() {
        let knowledgeNames = challenge.knowledgeNodeIDs.compactMap { appState.node(for: $0)?.name }
        let text = ChallengePromptFormatter().format(
            challenge: challenge,
            requirement: challengeRequirement,
            knowledgeNames: knowledgeNames
        )
        appState.statusMessage = SystemClipboard.copy(text)
            ? "已复制“\(challenge.title)”的实作题目"
            : "复制实作题目失败，请重试"
    }
}
