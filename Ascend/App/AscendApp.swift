import SwiftData
import SwiftUI

@main
struct AscendApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState: AppState
    @State private var appearancePreferences: AppearancePreferences

    init() {
        let container = PersistenceController.makeContainer(inMemory: AppRuntime.isRunningTests)
        let state = AppState(modelContainer: container)
        _appState = State(initialValue: state)
        _appearancePreferences = State(initialValue: .shared)
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
                .environment(appearancePreferences)
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
                .environment(appearancePreferences)
                .modelContainer(appState.modelContainer)
        }

        Window("入定", id: "focus") {
            FocusWindowView()
                .environment(appState)
                .environment(appearancePreferences)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)

        MenuBarExtra {
            MenuBarContentView()
                .environment(appState)
                .environment(appearancePreferences)
        } label: {
            MenuBarNotificationNavigationRouter()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)
    }
}
