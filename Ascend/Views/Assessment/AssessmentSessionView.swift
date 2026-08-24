import SwiftUI

struct AssessmentSessionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let session: AssessmentSession

    @State private var selectedAnswerIndex: Int?
    @State private var selectedReasoningIndex: Int?
    @State private var answerGate = AssessmentAnswerGate()
    @State private var answerValidationMessage: String?
    @State private var usedAssistance = false
    @State private var feedback: String?
    @State private var feedbackItem: AssessmentItem?
    @State private var requiresReviewGrade = false
    @State private var completed = false
    @State private var settlementNotice: String?

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
                    Text("第 \(responseCount + 1) 题 · 自适应 1～3 题（表现明确可提前完成）")
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
                    } else if completed {
                        completedView
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

    private var completedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 54))
                .foregroundStyle(AscendTheme.jade)

            VStack(spacing: 6) {
                Text(AscendTheme.isXuanqing ? "印证圆满 · 境界已定" : "验证完成")
                    .font(.system(.title2, design: AscendTheme.titleDesign))
                    .bold()
                Text("本次答题已正式印证掌握表现，境界与 XP 已同步结算。")
                    .font(.system(.callout, design: AscendTheme.titleDesign))
                    .foregroundStyle(.secondary)
            }

            if session.kind == .delayedReview {
                VStack(spacing: 10) {
                    Text("默认已按【良好 (Good)】推演下一次复习时间。如有需要可微调：")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        ForEach([MemoryReviewGrade.hard, .good, .easy]) { grade in
                            Button(grade.title) {
                                completeReview(grade)
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(14)
                .background(Color.primary.opacity(0.04))
                .clipShape(.rect(cornerRadius: 10))
            }

            Button("完成并返回", action: dismiss.callAsFunction)
                .buttonStyle(.borderedProminent)
                .tint(AscendTheme.jade)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
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

            if let settlementNotice {
                Label(settlementNotice, systemImage: "checkmark.circle")
                    .font(.callout)
                    .foregroundStyle(AscendTheme.jade)
            }

            Text(item.stem)
                .font(.title3)
                .bold()
                .fixedSize(horizontal: false, vertical: true)

            AssessmentOptionList(
                title: "你的判断",
                options: item.answerOptions,
                selection: $selectedAnswerIndex,
                isDisabled: answerGate.isReasoningUnlocked
            )

            if answerGate.isReasoningUnlocked {
                Text("判断正确且已锁定。现在请选择理由；掌握估计仍以首次判断为准。")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                AssessmentOptionList(
                    title: item.reasoningPrompt,
                    options: item.reasoningOptions,
                    selection: $selectedReasoningIndex,
                    isDisabled: false
                )

                Toggle("本题作答时使用了资料、提示或 AI", isOn: $usedAssistance)
                    .help("这次回答仍会保留，但不会用于更新掌握概率或 XP")

                HStack {
                    Button("跳过 / 未学过", systemImage: "forward.fill", action: { skip(item) })
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("提交本题", systemImage: "arrow.right.circle.fill", action: { submit(item) })
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedReasoningIndex == nil)
                }
            } else {
                if let answerValidationMessage {
                    Label(answerValidationMessage, systemImage: "xmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(AscendTheme.cinnabar)
                } else {
                    Text("先答对判断题，之后才会显示理由题。首次判断会用于掌握估计，重试不会覆盖首次表现。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("跳过 / 未学过", systemImage: "forward.fill", action: { skip(item) })
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("提交判断", systemImage: "arrow.right.circle.fill", action: { checkAnswer(item) })
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedAnswerIndex == nil)
                }
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

    private func submit(_ item: AssessmentItem) {
        guard answerGate.isReasoningUnlocked,
              let scoredAnswerIndex = answerGate.firstSelectedIndex,
              let selectedReasoningIndex else { return }
        do {
            let progress = try appState.recordAssessmentResponse(
                session: session,
                item: item,
                selectedAnswerIndex: scoredAnswerIndex,
                selectedReasoningIndex: selectedReasoningIndex,
                usedAssistance: usedAssistance
            )
            let response = appState.responses(for: session.id).first { $0.itemID == item.id }
            feedback = response?.isFullyCorrect == true ? "回答正确" : "需要巩固"
            feedbackItem = item
            requiresReviewGrade = progress.requiresReviewGrade
            completed = progress.isCompleted
            settlementNotice = nil
        } catch {
            appState.statusMessage = "提交测评失败：\(error.localizedDescription)"
        }
    }

    private func continueAfterFeedback() {
        feedback = nil
        feedbackItem = nil
        resetQuestionInput()
        if completed { dismiss() }
    }

    private func checkAnswer(_ item: AssessmentItem) {
        guard let selectedAnswerIndex else { return }
        if answerGate.submitAnswer(selectedAnswerIndex, correctIndex: item.correctAnswerIndex) {
            selectedReasoningIndex = nil
            answerValidationMessage = nil
        } else {
            self.selectedAnswerIndex = nil
            answerValidationMessage = "判断不正确，请重新选择；首次判断已保留，不会因重试变成正确。"
        }
    }

    private func skip(_ item: AssessmentItem) {
        do {
            let progress = try appState.skipAssessmentItem(session: session, item: item)
            feedback = nil
            feedbackItem = nil
            requiresReviewGrade = progress.requiresReviewGrade
            completed = progress.isCompleted
            resetQuestionInput()
            settlementNotice = completed ? nil : "上一题已跳过，并按未掌握表现实时结算"
        } catch {
            appState.statusMessage = "跳过题目失败：\(error.localizedDescription)"
        }
    }

    private func resetQuestionInput() {
        selectedAnswerIndex = nil
        selectedReasoningIndex = nil
        answerGate = AssessmentAnswerGate()
        answerValidationMessage = nil
        usedAssistance = false
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
