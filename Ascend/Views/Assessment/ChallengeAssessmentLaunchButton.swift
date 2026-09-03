import SwiftUI

/// 将挑战中的直接验证入口放在规则旁：资料或 Git 提交只建立学习基础，
/// 这里的实际作答才会形成接取后的可追溯挑战实据。
struct ChallengeAssessmentLaunchButton: View {
    @Environment(AppState.self) private var appState

    let challenge: Challenge

    @State private var session: AssessmentSession?
    @State private var isStarting = false
    @State private var preparationTask: Task<Void, Never>?

    private var cachedSession: AssessmentSession? {
        appState.cachedChallengeAssessment(for: challenge)
    }

    private var title: String {
        if isStarting || appState.isGeneratingAssessment { return "正在备题…" }
        return cachedSession == nil ? "知识验证 · 40% XP" : "知识验证 · 0 AI"
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: start) {
                Label(title, systemImage: "checkmark.seal")
            }
            .buttonStyle(.borderedProminent)
            .tint(AscendTheme.gold)
            .controlSize(.small)
            .disabled(isStarting || appState.isGeneratingAssessment)
            .help(cachedSession == nil
                ? "生成一轮选择题验证（1 次 AI）；通过可完成挑战并获得 40% 挑战 XP"
                : "选择题已在本地缓存；通过可完成挑战并获得 40% 挑战 XP，作答不调用 AI")

            if isStarting || appState.isGeneratingAssessment {
                Button("取消备题", role: .cancel) {
                    appState.cancelAssessmentGeneration()
                }
                .controlSize(.small)
                .help("取消当前 AI 备题请求，不会写入半成品题包")
            }
        }
        .sheet(item: $session) { session in
            AssessmentSessionView(session: session)
        }
    }

    private func start() {
        isStarting = true
        let taskID = UUID()
        let task = Task { @MainActor in
            defer {
                isStarting = false
                appState.finishAssessmentGenerationTask(id: taskID)
            }
            do {
                session = try await appState.startChallengeAssessment(for: challenge)
            } catch {
                if !Task.isCancelled {
                    appState.statusMessage = "开始挑战验证失败：\(error.localizedDescription)"
                }
            }
        }
        preparationTask = task
        appState.registerAssessmentGenerationTask(task, id: taskID)
    }
}
