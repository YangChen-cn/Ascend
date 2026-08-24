import SwiftUI

struct AssessmentLaunchButton: View {
    @Environment(AppState.self) private var appState
    let nodeID: UUID
    var title = "开始验证"
    var prominent = true

    @State private var session: AssessmentSession?
    @State private var isStarting = false

    var body: some View {
        Button(title, systemImage: "checkmark.seal", action: start)
            .buttonStyle(.borderedProminent)
            .disabled(isStarting || appState.isGeneratingAssessment)
            .help("生成 3–5 组双层情境选择题；提交后在本地判分")
            .sheet(item: $session) { session in
                AssessmentSessionView(session: session)
            }
    }

    private func start() {
        isStarting = true
        Task {
            defer { isStarting = false }
            do {
                session = try await appState.startAssessment(for: nodeID)
            } catch {
                appState.statusMessage = "生成测评失败：\(error.localizedDescription)"
            }
        }
    }
}
