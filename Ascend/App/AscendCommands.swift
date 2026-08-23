import SwiftUI

struct AscendCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("关于知境录") {
                appState.openSettings(section: .about)
            }
        }

        CommandMenu("研习") {
            Button("立即悟道分析", systemImage: "sparkles") {
                Task { await appState.runAnalysis() }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(appState.isAnalyzing)

            Button(appState.isCollecting ? "暂停自动采集" : "继续自动采集", systemImage: appState.isCollecting ? "pause" : "play") {
                appState.isCollecting.toggle()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .help) {
            Button("知境录 开源仓库…") {
                if let url = URL(string: "https://github.com/YangChen-cn/Ascend") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
