import SwiftUI

struct ChallengeCalloutView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitleView("已解锁挑战", systemImage: "flag.checkered")
            if let challenge = appState.challenges.first {
                Text(challenge.title)
                    .font(.title3)
                    .bold()
                Text("预计 \(challenge.estimatedMinutes) 分钟 · 可验证 \(challenge.knowledgeNodeIDs.count) 个知识点")
                    .foregroundStyle(.secondary)
                Button("开始挑战", systemImage: "play.fill", action: startChallenge)
                    .buttonStyle(.borderedProminent)
                    .tint(AscendTheme.cobalt)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            } else {
                ContentUnavailableView("暂无挑战", systemImage: "flag", description: Text("完成分析后会生成可验证的下一步。"))
            }
        }
    }

    private func startChallenge() {
        appState.selectedSection = .challenges
    }
}
