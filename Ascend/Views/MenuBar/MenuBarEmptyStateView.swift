import SwiftUI

struct MenuBarEmptyStateView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(MenuBarPalette.cinnabar(colorScheme))

                    Image(systemName: "sparkles")
                        .font(.system(size: 16))
                        .foregroundStyle(MenuBarPalette.gold(colorScheme))
                }

                Text("今日尚无研习记录")
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(MenuBarPalette.ink(colorScheme))

                Text("连接 Markdown 或 Git 后，\n知境录会自动记录你的学习与实践。")
                    .font(.system(size: 11))
                    .foregroundStyle(MenuBarPalette.secondaryInk(colorScheme))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)

            TargetedSettingsButton(section: .sources) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(MenuBarPalette.jade(colorScheme))
                    Text("添加学习来源")
                }
                .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            HStack(spacing: 12) {
                sourcePill(title: "Markdown", isConfigured: hasMarkdownSource)
                sourcePill(title: "Git", isConfigured: hasGitSource)
                sourcePill(title: "AI", isConfigured: hasAIConfigured)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    private var hasMarkdownSource: Bool {
        appState.sources.contains { $0.kind == .markdownDirectory && $0.isEnabled }
    }

    private var hasGitSource: Bool {
        appState.sources.contains {
            ($0.kind == .gitRepository || $0.kind == .remoteGitRepository || $0.kind == .remoteGitMarkdown) && $0.isEnabled
        }
    }

    private var hasAIConfigured: Bool {
        (appState.activeEndpoint ?? appState.endpointProfiles.first(where: \.isEnabled))?.selectedModelID.isEmpty == false
    }

    private func sourcePill(title: String, isConfigured: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: isConfigured ? "circle.fill" : "circle")
                .font(.system(size: 7))
                .foregroundStyle(
                    isConfigured
                        ? MenuBarPalette.jade(colorScheme)
                        : MenuBarPalette.secondaryInk(colorScheme).opacity(0.52)
                )
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(
                    MenuBarPalette.secondaryInk(colorScheme).opacity(isConfigured ? 1 : 0.62)
                )
        }
    }
}
