import SwiftUI

struct ReviewPlanCardView: View {
    @Environment(AppState.self) private var appState
    let plan: ReviewPlan
    let isStarting: Bool
    let onStart: (() -> Void)?

    private var node: KnowledgeNode? {
        appState.node(for: plan.knowledgeNodeID)
    }

    private var readiness: MasteryReadinessSnapshot? {
        appState.readiness(for: plan.knowledgeNodeID)
    }

    private var memory: MemoryState? {
        appState.memory(for: plan.knowledgeNodeID)
    }

    private var retention: Double? {
        appState.currentRetention(for: plan.knowledgeNodeID)
    }

    private var isDue: Bool {
        plan.status == "due"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 顶部信息：知窍名与领域/境界标签
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: isDue ? "clock.badge.exclamationmark.fill" : "calendar.badge.clock")
                    .font(.title3)
                    .foregroundStyle(isDue ? AscendTheme.cinnabar : AscendTheme.gold)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(node?.name ?? "未知知识点")
                        .font(.system(.headline, design: AscendTheme.titleDesign))
                        .bold()

                    if let domain = node?.domain {
                        HStack(spacing: 6) {
                            CelestialBadge(
                                title: domain,
                                systemImage: "folder.fill",
                                style: .astral
                            )
                            if let stage = readiness?.certifiedStage {
                                CelestialBadge(
                                    title: stage.rawValue,
                                    systemImage: "seal.fill",
                                    style: .gold
                                )
                            }
                        }
                    }
                }

                Spacer()

                if isDue {
                    CelestialBadge(
                        title: "今日温故",
                        systemImage: "leaf.fill",
                        style: .jade
                    )
                } else if plan.status == "completed" {
                    CelestialBadge(
                        title: "已完成温故",
                        systemImage: "checkmark.circle.fill",
                        style: .jade
                    )
                } else {
                    CelestialBadge(
                        title: "排期推演中",
                        systemImage: "clock.arrow.circlepath",
                        style: .neutral
                    )
                }
            }

            // 中部：复习原因与推演计划
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(isDue ? "到期时间：" : "预计时间：")
                        .font(.system(.caption, design: .serif))
                        .foregroundStyle(.secondary)
                    Text(plan.scheduledAt, format: .dateTime.year().month().day().hour().minute())
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(isDue ? AscendTheme.cinnabar : .secondary)
                        .bold(isDue)
                }

                if !plan.reason.isEmpty {
                    Text(plan.reason)
                        .font(.system(.callout, design: AscendTheme.titleDesign))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Divider()
                .overlay(AscendTheme.gold.opacity(0.12))

            // 底部：记忆状态语义与操作按钮（FSRS 精确数字收进 tooltip，不作为卡片主视觉）
            HStack(alignment: .center, spacing: 16) {
                if let retentionValue = retention {
                    CelestialBadge(
                        title: memoryLevelTitle(retentionValue),
                        systemImage: "brain.head.profile",
                        style: retentionValue >= 60 ? .jade : .cinnabar
                    )
                    .help("当前记忆可提取率 \(Int(retentionValue.rounded()))%")
                }

                if let memory {
                    HStack(spacing: 8) {
                        Label("已复习 \(memory.reps) 次", systemImage: "arrow.counterclockwise")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let onStart, isDue {
                    Button {
                        onStart()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "brain.head.profile")
                            Text("开始温故")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AscendTheme.jade)
                } else if let onStart, !isDue, plan.status != "completed" {
                    Button("提前温故", systemImage: "sparkles", action: onStart)
                        .buttonStyle(.bordered)
                }
            }
        }
        .panelCard(highlighted: isDue)
    }

    /// 温故是回忆练习不是考试：卡片上只呈现三档语义
    private func memoryLevelTitle(_ value: Double) -> String {
        switch value {
        case ..<60: "记忆需要加固"
        case ..<85: "略有生疏"
        default: "记得牢"
        }
    }
}
