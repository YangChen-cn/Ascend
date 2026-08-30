import SwiftUI

struct AscendCommands: Commands {
    let appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("关于知境录") {
                appState.openSettings(section: .about)
            }
        }

        CommandMenu("日课") {
            Button("新增任务…", systemImage: "plus.circle") {
                openMainWindow()
                appState.isPresentingDailyTaskComposer = true
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("入定 · 开始专注", systemImage: "flame.fill") {
                openMainWindow()
                appState.isPresentingFocusImmersion = true
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
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

    /// ⌘N 时主窗口可能尚未打开；openWindow 对已开窗口幂等。
    private func openMainWindow() {
        openWindow(id: "main")
    }
}
