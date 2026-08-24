import SwiftUI

struct AssessmentSessionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let session: AssessmentSession

    @State private var selectedAnswerIndex: Int?
    @State private var selectedReasoningIndex: Int?
    @State private var usedAssistance = false
    @State private var feedback: String?
    @State private var feedbackItem: AssessmentItem?
    @State private var requiresReviewGrade = false
    @State private var completed = false

    private var currentItem: AssessmentItem? {
        appState.currentItem(for: session)
    }

    private var responseCount: Int {
        appState.responses(for: session.id).count(where: { !$0.isInvalidated })
    }

    private var measuredNodeCount: Int {
        Set(appState.items(for: session.id).map(\.knowledgeNodeID)).count
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.kind == .delayedReview ? "主动检索复习" : (measuredNodeCount > 1 ? "领域综合验证" : "真实掌握验证"))
                        .font(.title2)
                        .bold()
                    Text("第 \(min(responseCount + 1, 5)) 组 · 最少 3 组，最多 5 组")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("关闭", systemImage: "xmark", action: dismiss.callAsFunction)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .help("关闭测评")
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let feedback, let feedbackItem {
                        feedbackView(feedback: feedback, item: feedbackItem)
                    } else if requiresReviewGrade {
                        reviewGradeView
                    } else if completed {
                        ContentUnavailableView(
                            "验证完成",
                            systemImage: "checkmark.seal.fill",
                            description: Text("掌握估计已根据本次可验证表现更新。")
                        )
                    } else if let item = currentItem {
                        questionView(item: item)
                    } else {
                        ProgressView("正在准备下一题…")
                            .frame(maxWidth: .infinity, minHeight: 240)
                    }
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 680, minHeight: 620)
        .interactiveDismissDisabled(!completed && session.statusRawValue != "completed")
    }

    private func questionView(item: AssessmentItem) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(item.tier.title, systemImage: "scope")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let nodeName = appState.node(for: item.knowledgeNodeID)?.name, measuredNodeCount > 1 {
                Label("本题验证 · \(nodeName)", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.callout)
                    .foregroundStyle(AscendTheme.gold)
            }

            Text(item.stem)
                .font(.title3)
                .bold()
                .fixedSize(horizontal: false, vertical: true)

            AssessmentOptionList(
                title: "你的判断",
                options: item.answerOptions,
                selection: $selectedAnswerIndex,
                isDisabled: false
            )

            AssessmentOptionList(
                title: item.reasoningPrompt,
                options: item.reasoningOptions,
                selection: $selectedReasoningIndex,
                isDisabled: false
            )

            Toggle("本题作答时使用了资料、提示或 AI", isOn: $usedAssistance)
                .help("这次回答仍会保留，但不会用于更新掌握概率或 XP")

            HStack {
                Spacer()
                Button("提交本题", systemImage: "arrow.right.circle.fill", action: { submit(item) })
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedAnswerIndex == nil || selectedReasoningIndex == nil)
            }
        }
    }

    private func feedbackView(feedback: String, item: AssessmentItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(feedback, systemImage: feedback.hasPrefix("回答正确") ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(feedback.hasPrefix("回答正确") ? AscendTheme.jade : AscendTheme.cinnabar)
            Text(item.explanation)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                Text("正确答案：\(item.answerOptions[item.correctAnswerIndex])")
                Text("正确理由：\(item.reasoningOptions[item.correctReasoningIndex])")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            if !item.misconceptionTags.isEmpty {
                Text("相关误区：\(item.misconceptionTags.joined(separator: "、"))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("题目有歧义", systemImage: "exclamationmark.bubble", action: { invalidate(item) })
                    .buttonStyle(.bordered)
                Spacer()
                Button(completed ? "完成" : "继续", systemImage: completed ? "checkmark" : "arrow.right", action: continueAfterFeedback)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .background(Color.primary.opacity(0.04))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var reviewGradeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("本轮检索全部正确", systemImage: "brain.head.profile.fill")
                .font(.title3)
                .foregroundStyle(AscendTheme.jade)
            Text("请选择这次从记忆中提取答案的难度。该反馈只在实际答题成功后用于 FSRS。")
                .foregroundStyle(.secondary)
            HStack {
                ForEach([MemoryReviewGrade.hard, .good, .easy]) { grade in
                    Button(grade.title, action: { completeReview(grade) })
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func submit(_ item: AssessmentItem) {
        guard let selectedAnswerIndex, let selectedReasoningIndex else { return }
        do {
            let progress = try appState.recordAssessmentResponse(
                session: session,
                item: item,
                selectedAnswerIndex: selectedAnswerIndex,
                selectedReasoningIndex: selectedReasoningIndex,
                usedAssistance: usedAssistance
            )
            let response = appState.responses(for: session.id).first { $0.itemID == item.id }
            feedback = response?.isFullyCorrect == true ? "回答正确" : "需要巩固"
            feedbackItem = item
            requiresReviewGrade = progress.requiresReviewGrade
            completed = progress.isCompleted
        } catch {
            appState.statusMessage = "提交测评失败：\(error.localizedDescription)"
        }
    }

    private func continueAfterFeedback() {
        feedback = nil
        feedbackItem = nil
        selectedAnswerIndex = nil
        selectedReasoningIndex = nil
        usedAssistance = false
        if completed { dismiss() }
    }

    private func completeReview(_ grade: MemoryReviewGrade) {
        do {
            try appState.completeReviewAssessment(session: session, grade: grade)
            requiresReviewGrade = false
            completed = true
        } catch {
            appState.statusMessage = "完成复习失败：\(error.localizedDescription)"
        }
    }

    private func invalidate(_ item: AssessmentItem) {
        do {
            try appState.invalidateAssessmentItem(item)
            continueAfterFeedback()
        } catch {
            appState.statusMessage = "作废题目失败：\(error.localizedDescription)"
        }
    }
}
