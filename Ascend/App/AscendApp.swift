import SwiftData
import SwiftUI

@main
struct AscendApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState: AppState

    init() {
        let container = PersistenceController.makeContainer()
        _appState = State(initialValue: AppState(modelContainer: container))
    }

    var body: some Scene {
        WindowGroup("知境录", id: "main") {
            ContentView()
                .environment(appState)
                .modelContainer(appState.modelContainer)
                .frame(minWidth: 1_180, minHeight: 760)
        }
        .defaultSize(width: 1_440, height: 900)
        .commands {
            AscendCommands(appState: appState)
        }

        Settings {
            SettingsRootView()
                .environment(appState)
                .modelContainer(appState.modelContainer)
        }

        MenuBarExtra("知境录", systemImage: appState.isCollecting ? "chart.line.uptrend.xyaxis" : "pause.circle") {
            MenuBarContentView()
                .environment(appState)
        }
    }
}
