import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppearancePreferences.self) private var appearancePreferences
    @State private var presentedAssessmentSession: AssessmentSession?

    private var appearanceMode: AppearanceMode {
        appearancePreferences.appearanceMode
    }

    var body: some View {
        Group {
            if appState.requiresMeasurementReset {
                MeasurementResetView(allowsDeferral: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AscendTheme.background(for: appearanceMode.colorScheme ?? .light))
            } else {
                mainContent
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
        .tint(AscendTheme.jade)
        .accentColor(AscendTheme.jade)
        .sheet(item: $presentedAssessmentSession) { session in
            AssessmentSessionView(session: session)
        }
        .sheet(
            isPresented: Binding(
                get: { appState.isPresentingDailyTaskComposer },
                set: { appState.isPresentingDailyTaskComposer = $0 }
            )
        ) {
            DailyTaskComposerSheet(initialKind: .todo)
        }
        .overlay {
            if appState.isPresentingFocusImmersion {
                FocusImmersionView()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: appState.isPresentingFocusImmersion)
        // 只有通知点击、菜单栏快捷操作或页面按钮才会请求打开题目。
        // 已备题包仅保留为可研习状态，绝不在打开主窗口时抢占用户注意力。
        .onAppear(perform: presentExplicitlyRequestedAssessment)
        .onChange(of: appState.requestedAssessmentSessionID) { _, _ in
            presentExplicitlyRequestedAssessment()
        }
    }

    private var mainContent: some View {
        @Bindable var appState = appState
        return NavigationSplitView {
            SidebarView(selection: $appState.selectedSection)
                .navigationSplitViewColumnWidth(min: 205, ideal: 225, max: 250)
        } detail: {
            DetailRouterView(section: appState.selectedSection)
                .background(AscendTheme.background(for: appearanceMode.colorScheme ?? .light))
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ActiveModelMenu()
                Button("立即分析", systemImage: "sparkles", action: runAnalysis)
                    .disabled(appState.isAnalyzing)
                    .help("扫描新活动并生成学习分析")
            }
        }
    }

    private func runAnalysis() {
        Task { await appState.runAnalysis() }
    }

    private func presentExplicitlyRequestedAssessment() {
        if let requestedID = appState.requestedAssessmentSessionID,
           let requested = appState.assessmentSessions.first(where: { $0.id == requestedID }) {
            appState.requestedAssessmentSessionID = nil
            presentedAssessmentSession = requested
        }
    }
}
