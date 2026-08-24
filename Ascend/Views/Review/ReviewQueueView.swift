import SwiftUI

struct ReviewQueueView: View {
    @Environment(AppState.self) private var appState

    @State private var assessmentSession: AssessmentSession?
    @State private var startingPlanID: UUID?

    private var duePlans: [ReviewPlan] {
        appState.reviewPlans
            .filter { $0.status == "due" }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    private var scheduledPlans: [ReviewPlan] {
        appState.reviewPlans
            .filter { $0.status == "scheduled" }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("到期复习")
                        .font(.largeTitle)
                        .bold()
                    Text("重新从记忆中作答，而不是重读笔记。答错会缩短复习间隔；全部答对后再选择 Hard、Good 或 Easy。")
                        .foregroundStyle(.secondary)
                }

                if duePlans.isEmpty {
                    ContentUnavailableView(
                        "当前没有到期复习",
                        systemImage: "checkmark.circle",
                        description: Text(scheduledPlans.isEmpty
                            ? "完成首次验证后，系统会自动安排次日的延迟检索。"
                            : "已安排的复习会在到期后出现在这里。")
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    ReviewPlanSectionView(
                        title: "现在需要复习",
                        plans: duePlans,
                        startingPlanID: startingPlanID,
                        nodeName: nodeName,
                        retention: retention,
                        start: startReview
                    )
                }

                if !scheduledPlans.isEmpty {
                    ReviewPlanSectionView(
                        title: "即将到期",
                        plans: scheduledPlans,
                        startingPlanID: nil,
                        nodeName: nodeName,
                        retention: retention,
                        start: nil
                    )
                }
            }
            .frame(maxWidth: 820, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("到期复习")
        .sheet(item: $assessmentSession, content: AssessmentSessionView.init)
    }

    private func nodeName(for plan: ReviewPlan) -> String {
        appState.node(for: plan.knowledgeNodeID)?.name ?? "未知知识点"
    }

    private func retention(for plan: ReviewPlan) -> Double? {
        appState.currentRetention(for: plan.knowledgeNodeID)
    }

    private func startReview(_ plan: ReviewPlan) {
        guard startingPlanID == nil else { return }
        startingPlanID = plan.id
        Task {
            defer { startingPlanID = nil }
            do {
                assessmentSession = try await appState.startReviewAssessment(for: plan.id)
            } catch {
                appState.statusMessage = "准备到期复习失败：\(error.localizedDescription)"
            }
        }
    }
}
