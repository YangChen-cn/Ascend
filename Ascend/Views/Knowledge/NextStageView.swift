import SwiftUI

struct NextStageView: View {
    @Environment(AppState.self) private var appState
    let nodeID: UUID
    let readiness: MasteryReadinessSnapshot

    private var nextStage: MasteryStage? {
        readiness.historicalStage.next
    }

    private var nextReview: ReviewPlan? {
        appState.reviewPlans(for: nodeID).first { $0.status == "scheduled" }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading) {
                    SectionTitleView("下一境")
                    Text(nextStage?.rawValue ?? "已臻通达")
                        .font(.title2)
                        .bold()
                        .foregroundStyle(AscendTheme.cobalt)
                }
                Spacer()
                Text("历史 \(Int(readiness.historicalComposite.rounded())) · 当前 \(Int(readiness.currentComposite.rounded()))")
                    .foregroundStyle(.secondary)
            }
            ProgressView(
                value: readiness.historicalComposite,
                total: Double(nextStage?.minimumScore ?? 100)
            )
                .tint(AscendTheme.cobalt)
            if let nextStage {
                Label("真实已验证证据需将历史掌握提升至 \(Int(nextStage.minimumScore))", systemImage: "checkmark.seal")
            } else {
                Label("已达到最高知识境界；当前状态仍会受记忆保持影响", systemImage: "seal.fill")
            }
            if let nextReview {
                Label(
                    "复习已安排：\(nextReview.scheduledAt.formatted(date: .abbreviated, time: .shortened))",
                    systemImage: "calendar.badge.checkmark"
                )
            } else {
                Text("挑战与复习只有在产生真实学习记录并经验证后才会影响掌握度与知验。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("接受破境挑战", systemImage: "flag.checkered", action: openChallenges)
                    .buttonStyle(.borderedProminent)
                Button("安排复习", systemImage: "calendar", action: scheduleReview)
                    .disabled(nextReview != nil)
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
        let scheduledAt = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        do {
            try appState.scheduleReview(
                for: nodeID,
                scheduledAt: scheduledAt,
                reason: "巩固当前记忆保持（用户手动安排）"
            )
        } catch {
            appState.statusMessage = "安排复习失败：\(error.localizedDescription)"
        }
    }
}
