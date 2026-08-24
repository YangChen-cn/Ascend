import SwiftUI

/// 「周天引荐 · 修业指引卡」
/// 在今日大盘右侧栏展示基于先导依赖图谱与境界门槛推演出的下一步修习引荐知窍。
struct RecommendationRailSectionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    private var recommendations: [LearningRecommendation] {
        Array(appState.learningRecommendations.prefix(3))
    }

    var body: some View {
        if !recommendations.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .foregroundStyle(AscendTheme.gold)
                    Text(AscendTheme.isXuanqing ? "周天引荐 · 下一步修业" : "智能修业推荐")
                        .font(.system(.headline, design: AscendTheme.titleDesign))
                        .bold()

                    Spacer()

                    ClassicalSealMark(text: "荐读", shape: .square, style: .gold, carving: .intaglio, size: 20)
                }

                VStack(spacing: 8) {
                    ForEach(recommendations) { item in
                        Button {
                            open(item)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                typeIcon(for: item.type)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(item.title)
                                            .font(.subheadline)
                                            .bold()
                                            .foregroundStyle(Color.primary)
                                            .lineLimit(1)

                                        Text(item.type.title)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(typeColor(for: item.type))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1.5)
                                            .background(typeColor(for: item.type).opacity(0.12))
                                            .clipShape(Capsule())
                                    }

                                    Text(item.reason)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer(minLength: 4)

                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary.opacity(0.6))
                                    .padding(.top, 4)
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.primary.opacity(0.025))
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("推荐知窍：\(item.title)，\(item.type.title)")
                    }
                }
            }
        }
    }

    private func typeIcon(for type: LearningRecommendationType) -> some View {
        ZStack {
            Circle()
                .fill(typeColor(for: type).opacity(0.12))
                .frame(width: 26, height: 26)
            Image(systemName: iconName(for: type))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(typeColor(for: type))
        }
    }

    private func iconName(for type: LearningRecommendationType) -> String {
        switch type {
        case .nextConcept: "arrow.up.forward.circle.fill"
        case .practice: "hammer.fill"
        case .review: "leaf.fill"
        case .challenge: "flag.fill"
        case .continue: "play.fill"
        }
    }

    private func typeColor(for type: LearningRecommendationType) -> Color {
        switch type {
        case .nextConcept: AscendTheme.gold
        case .practice, .continue: AscendTheme.jade
        case .review: AscendTheme.jade
        case .challenge: AscendTheme.cinnabar
        }
    }

    private func open(_ item: LearningRecommendation) {
        if item.type == .challenge, item.challengeID != nil {
            appState.selectedSection = .challenges
        } else if item.type == .review {
            appState.selectedSection = .review
        } else {
            appState.selectedKnowledgeNodeID = item.knowledgeNodeID
            appState.selectedSection = .knowledge
        }
    }
}
