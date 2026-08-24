import AppKit
import SwiftUI

struct MenuBarNotificationNavigationRouter: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        MenuBarHeritageIcon(isActive: appState.isCollectionSchedulerRunning)
            .accessibilityLabel("知境录")
            .onChange(of: appState.pendingNotificationDestination, initial: true) { _, destination in
                guard let destination else { return }
                route(to: destination)
            }
    }

    private func route(to destination: NotificationNavigationDestination) {
        appState.pendingNotificationDestination = nil
        switch destination {
        case .assessment:
            appState.selectedSection = .today
            if let domainName = appState.preparedVerificationDomainNames.first,
               let session = appState.preparedDomainAssessment(for: domainName) {
                appState.requestedAssessmentSessionID = session.id
            } else {
                appState.statusMessage = "当前没有已准备好的验证题包"
            }
            openMainWindow()
        case .today:
            appState.selectedSection = .today
            openMainWindow()
        case .review:
            appState.selectedSection = .review
            openMainWindow()
        case .challenges:
            appState.selectedSection = .challenges
            openMainWindow()
        case .notificationSettings:
            appState.openSettings(section: .notifications)
        case .knowledge(let nodeID):
            appState.selectedKnowledgeNodeID = nodeID
            appState.selectedSection = .knowledge
            openMainWindow()
        }
    }

    private func openMainWindow() {
        openWindow(id: "main")
        Task { @MainActor in
            await Task.yield()
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
