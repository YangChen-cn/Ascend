import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppearancePreferences.self) private var appearancePreferences
    @AppStorage("lastAutomaticVerificationPromptDay") private var lastAutomaticVerificationPromptDay = ""
    @State private var automaticAssessmentSession: AssessmentSession?

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
        .sheet(item: $automaticAssessmentSession) { session in
            AssessmentSessionView(session: session)
        }
        .onAppear(perform: presentAssessmentOnUserEntry)
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
            automaticAssessmentSession = requested
        }
    }

    private func presentAssessmentOnUserEntry() {
        presentExplicitlyRequestedAssessment()
        guard automaticAssessmentSession == nil else { return }
        let day = String(Int(Calendar.current.startOfDay(for: .now).timeIntervalSince1970))
        guard !appState.isAnalyzing,
              lastAutomaticVerificationPromptDay != day,
              let domainName = appState.preparedVerificationDomainNames.first,
              let prepared = appState.preparedDomainAssessment(for: domainName) else { return }
        lastAutomaticVerificationPromptDay = day
        automaticAssessmentSession = prepared
    }
}
