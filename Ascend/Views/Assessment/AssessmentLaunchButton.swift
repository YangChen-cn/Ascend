import SwiftUI

struct AssessmentLaunchButton: View {
    @Environment(AppState.self) private var appState
    let nodeID: UUID
    var title: String? = nil
    var prominent = true
    var compact = false
    var showSubtitle = true

    @State private var session: AssessmentSession?
    @State private var isStarting = false
    @State private var preparationTask: Task<Void, Never>?

    private var cachedSession: AssessmentSession? {
        appState.cachedAssessment(for: nodeID)
    }

    private var readiness: MasteryReadinessSnapshot? {
        appState.readiness(for: nodeID)
    }

    private var isBreakthroughCandidate: Bool {
        guard let readiness else { return false }
        return readiness.certifiedStage.level >= MasteryStage.proficient.level || readiness.currentComposite >= 45.0
    }

    private var buttonTitle: String {
        if isStarting || appState.isGeneratingAssessment {
            return "正在准备…"
        }
        if let title {
            return title
        }
        if isBreakthroughCandidate {
            return "主动印证"
        }
        return "主动研习"
    }

    private var statusBadgeText: String? {
        if cachedSession != nil {
            return compact ? "0 AI" : "已备好 · 0 AI"
        }
        return nil
    }

    private var subtitleText: String {
        if isBreakthroughCandidate {
            return "完成轻量验证后可尝试突破融会"
        }
        return "1～3 题，可加快成长"
    }

    private var helpText: String {
        if cachedSession != nil {
            return "\(subtitleText)（本地题库已就绪，0 AI）"
        } else {
            return "\(subtitleText)（本地暂无缓存题包，点击后将发起 1 次 AI 备题请求）"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            launchButton
                .controlSize(compact ? .small : .small)
                .disabled(isStarting || appState.isGeneratingAssessment)
                .help(helpText)

            if isStarting || appState.isGeneratingAssessment {
                Button("取消备题", role: .cancel) {
                    appState.cancelAssessmentGeneration()
                }
                .controlSize(.small)
            }

            if showSubtitle && !compact {
                Text(subtitleText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(item: $session) { session in
            AssessmentSessionView(session: session)
        }
    }

    @ViewBuilder
    private var launchButton: some View {
        if prominent {
            rawButton.buttonStyle(.borderedProminent)
        } else {
            rawButton.buttonStyle(.bordered)
        }
    }

    private var rawButton: some View {
        Button(action: start) {
            HStack(spacing: 4) {
                Image(systemName: isBreakthroughCandidate ? "checkmark.seal" : "bolt.badge.clock")
                    .font(.system(size: 11, weight: .medium))
                Text(buttonTitle)
                    .font(.callout.weight(.medium))
                if let badge = statusBadgeText {
                    Text(badge)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, -1)
        }
    }

    private func start() {
        if let cached = cachedSession {
            session = cached
            return
        }
        isStarting = true
        let taskID = UUID()
        let task = Task { @MainActor in
            defer {
                isStarting = false
                appState.finishAssessmentGenerationTask(id: taskID)
            }
            do {
                session = try await appState.startAssessment(for: nodeID)
            } catch {
                if !Task.isCancelled {
                    appState.statusMessage = "生成研习题失败：\(error.localizedDescription)"
                }
            }
        }
        preparationTask = task
        appState.registerAssessmentGenerationTask(task, id: taskID)
    }
}
