import SwiftUI

struct NextStageView: View {
    @Environment(AppState.self) private var appState
    let mastery: MasteryState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading) {
                    SectionTitleView("下一境")
                    Text(mastery.stage.next?.rawValue ?? "已臻通达")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(AscendTheme.cobalt)
                }
                Spacer()
                Text("掌握 \(Int(mastery.composite.rounded()))")
                    .foregroundStyle(.secondary)
            }
            ProgressView(
                value: mastery.composite,
                total: Double(mastery.stage.next?.minimumScore ?? 100)
            )
                .tint(AscendTheme.cobalt)
            Label("完成 1 次跨模块重构", systemImage: "circle")
            Label("在 7 天后通过一次复习", systemImage: "circle")
            Label("独立解决 1 个并发更新问题", systemImage: "circle")
            HStack {
                Button("接受破境挑战", systemImage: "flag.checkered", action: openChallenges)
                    .buttonStyle(.borderedProminent)
                Button("安排复习", systemImage: "calendar", action: scheduleReview)
            }
        }
        .padding(18)
        .background(AscendTheme.cobalt.opacity(0.05))
        .clipShape(.rect(cornerRadius: 10))
    }

    private func openChallenges() {
        appState.selectedSection = .challenges
    }

    private func scheduleReview() {
        appState.statusMessage = "已将该知识点加入 7 天后的复习队列"
    }
}
