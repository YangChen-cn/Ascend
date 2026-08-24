import AppKit
import SwiftUI

struct MenuBarRecommendationSection: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var hoveredID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("今日修炼")
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(MenuBarPalette.ink(colorScheme))

            VStack(spacing: 2) {
                ForEach(Array(appState.learningRecommendations.prefix(3).enumerated()), id: \.element.id) { index, item in
                    Button(action: { open(item) }) {
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(MenuBarPalette.gold(colorScheme))
                                .frame(width: 14, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(item.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(MenuBarPalette.ink(colorScheme))
                                        .lineLimit(1)

                                    Text(item.type.title)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(tint(for: item.type))
                                }

                                Text(item.reason)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(MenuBarPalette.secondaryInk(colorScheme))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer(minLength: 4)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(MenuBarPalette.secondaryInk(colorScheme).opacity(0.55))
                                .padding(.top, 4)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(hoveredID == item.id ? MenuBarPalette.hoverFill(colorScheme) : .clear)
                        )
                        .contentShape(.rect)
                    }
                    .buttonStyle(MenuBarPressButtonStyle())
                    .onHover { hovering in
                        hoveredID = hovering ? item.id : nil
                    }
                    .accessibilityLabel("第 \(index + 1) 项，\(item.title)，\(item.type.title)，\(item.reason)")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
    }

    private func tint(for type: LearningRecommendationType) -> Color {
        switch type {
        case .review: MenuBarPalette.cinnabar(colorScheme)
        case .practice, .continue: MenuBarPalette.jade(colorScheme)
        case .nextConcept: MenuBarPalette.jade(colorScheme)
        case .challenge: MenuBarPalette.gold(colorScheme)
        }
    }

    private func open(_ recommendation: LearningRecommendation) {
        if recommendation.type == .challenge, recommendation.challengeID != nil {
            appState.selectedSection = .challenges
        } else if recommendation.type == .review {
            appState.selectedSection = .review
        } else {
            appState.selectedKnowledgeNodeID = recommendation.knowledgeNodeID
            appState.selectedSection = .knowledge
        }
        openWindow(id: "main")
        dismiss()
        Task { @MainActor in
            await Task.yield()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
