import SwiftUI

struct AscendCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandMenu("学习") {
            Button("立即分析", systemImage: "sparkles") {
                Task { await appState.runAnalysis() }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(appState.isAnalyzing)

            Button(appState.isCollecting ? "暂停采集" : "继续采集", systemImage: appState.isCollecting ? "pause" : "play") {
                appState.isCollecting.toggle()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }
    }
}
