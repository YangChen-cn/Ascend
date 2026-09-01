import SwiftUI

struct DomainAssessmentLaunchButton: View {
    @Environment(AppState.self) private var appState

    let domainName: String
    var compact = false

    @State private var session: AssessmentSession?
    @State private var isPreparing = false
    @State private var preparationTask: Task<Void, Never>?

    private var cachedSession: AssessmentSession? {
        appState.cachedDomainAssessment(for: domainName) ?? appState.preparedDomainAssessment(for: domainName)
    }

    private var buttonTitle: String {
        if isPreparing || appState.isGeneratingAssessment { return "正在备题…" }
        if cachedSession != nil { return "主动研习" }
        return "准备研习题"
    }

    private var helpText: String {
        cachedSession == nil
            ? "生成覆盖“\(domainName)”知识点的研习题包（1 次 AI 请求）"
            : "“\(domainName)”研习题包已就绪（0 AI）"
    }

    var body: some View {
        HStack(spacing: 8) {
        Button(action: openOrPrepare) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.badge.clock")
                Text(buttonTitle)
                if cachedSession != nil && !compact {
                    Text("0 AI")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(compact ? .mini : .regular)
        .disabled(isPreparing || appState.isGeneratingAssessment)
        .help(helpText)
        if isPreparing || appState.isGeneratingAssessment {
            Button("取消备题", role: .cancel) {
                appState.cancelAssessmentGeneration()
            }
            .controlSize(.small)
        }
        }
        .sheet(item: $session) { session in
            AssessmentSessionView(session: session)
        }
    }

    private func openOrPrepare() {
        if let cached = cachedSession {
            session = cached
            return
        }
        isPreparing = true
        let taskID = UUID()
        let task = Task { @MainActor in
            defer {
                isPreparing = false
                appState.finishAssessmentGenerationTask(id: taskID)
            }
            do {
                session = try await appState.startDomainAssessment(for: domainName)
            } catch {
                if !Task.isCancelled {
                    appState.statusMessage = "准备研习题失败：\(error.localizedDescription)"
                }
            }
        }
        preparationTask = task
        appState.registerAssessmentGenerationTask(task, id: taskID)
    }
}
