import SwiftData
import SwiftUI

@main
struct AscendApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState: AppState

    init() {
        let container = PersistenceController.makeContainer()
        let state = AppState(modelContainer: container)
        _appState = State(initialValue: state)
        if !AppRuntime.isRunningTests {
            appDelegate.startAutomation = { [weak state] in
                await state?.startAutomation()
            }
            appDelegate.handleNotificationNavigation = { [weak state] destination in
                state?.pendingNotificationDestination = destination
            }
        }
    }

    var body: some Scene {
        Window("知境录", id: "main") {
            ContentView()
                .environment(appState)
                .modelContainer(appState.modelContainer)
                .frame(minWidth: 760, minHeight: 560)
        }
        .defaultSize(width: 1_280, height: 820)
        .defaultPosition(.center)
        .defaultLaunchBehavior(.suppressed)
        .commands {
            AscendCommands(appState: appState)
        }

        Settings {
            SettingsRootView()
                .environment(appState)
                .modelContainer(appState.modelContainer)
        }

        MenuBarExtra {
            MenuBarContentView()
                .environment(appState)
        } label: {
            MenuBarNotificationNavigationRouter()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)
    }
}
