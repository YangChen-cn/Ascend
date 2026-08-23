import SwiftUI

struct MenuBarContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("打开知境录", systemImage: "macwindow", action: openMainWindow)
        Divider()
        Label(appState.isCollecting ? "正在采集" : "采集已暂停", systemImage: appState.isCollecting ? "circle.fill" : "pause.circle")
        Button(appState.isCollecting ? "暂停采集" : "继续采集", systemImage: appState.isCollecting ? "pause" : "play", action: toggleCollection)
        Button("立即分析", systemImage: "sparkles", action: runAnalysis)
            .disabled(appState.isAnalyzing)

        if !appState.endpointProfiles.isEmpty {
            Divider()
            Menu("当前模型", systemImage: "cpu") {
                ForEach(appState.endpointProfiles) { profile in
                    ForEach(profile.cachedModelIDs, id: \.self) { modelID in
                        Button(modelID, action: { appState.selectModel(profileID: profile.id, modelID: modelID) })
                    }
                }
            }
        }
        Divider()
        TargetedSettingsButton(section: .general) { Text("设置…") }
        Button("退出知境录", systemImage: "power", action: quit)
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func toggleCollection() {
        appState.isCollecting.toggle()
    }

    private func runAnalysis() {
        Task { await appState.runAnalysis() }
    }

    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
