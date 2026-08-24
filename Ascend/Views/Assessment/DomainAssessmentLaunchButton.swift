import SwiftUI

struct DomainAssessmentLaunchButton: View {
    @Environment(AppState.self) private var appState

    let domainName: String
    var compact = false

    @State private var session: AssessmentSession?
    @State private var isPreparing = false

    var body: some View {
        Button(buttonTitle, systemImage: "checkmark.seal", action: openOrPrepare)
            .buttonStyle(.borderedProminent)
            .controlSize(compact ? .mini : .regular)
            .disabled(isPreparing || appState.isGeneratingAssessment)
            .help(helpText)
            .sheet(item: $session) { session in
                AssessmentSessionView(session: session)
            }
    }

    private var preparedSession: AssessmentSession? {
        appState.preparedDomainAssessment(for: domainName)
    }

    private var buttonTitle: String {
        if preparedSession != nil { return "开始领域验证" }
        if isPreparing || appState.isGeneratingAssessment { return "正在备题" }
        return "准备领域验证"
    }

    private var helpText: String {
        preparedSession == nil
            ? "预生成一轮覆盖最多 5 个缺测知识点的题包"
            : "题包已就绪；一轮最多 5 组题，覆盖多个知识点"
    }

    private func openOrPrepare() {
        if let preparedSession {
            session = preparedSession
            return
        }
        isPreparing = true
        Task {
            defer { isPreparing = false }
            do {
                session = try await appState.startDomainAssessment(for: domainName)
            } catch {
                appState.statusMessage = "准备领域验证失败：\(error.localizedDescription)"
            }
        }
    }
}
