import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppearanceMode.light.rawValue
    @AppStorage("visualTheme") private var visualThemeRaw = VisualTheme.defaultTheme.rawValue

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .light
    }

    var body: some View {
        @Bindable var appState = appState
        NavigationSplitView {
            SidebarView(selection: $appState.selectedSection)
                .navigationSplitViewColumnWidth(min: 205, ideal: 225, max: 250)
        } detail: {
            DetailRouterView(section: appState.selectedSection)
                .background(AscendTheme.background(for: appearanceMode.colorScheme ?? .light))
        }
        .preferredColorScheme(appearanceMode.colorScheme)
        .tint(themeAccent)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ActiveModelMenu()
                Button("立即分析", systemImage: "sparkles", action: runAnalysis)
                    .disabled(appState.isAnalyzing)
                    .help("扫描新活动并生成学习分析")
            }
        }
    }

    private var themeAccent: Color {
        // Reading AppStorage here makes theme changes invalidate the view without
        // destroying navigation, selection, sheets, or scroll position.
        _ = VisualTheme(rawValue: visualThemeRaw) ?? .defaultTheme
        return AscendTheme.jade
    }

    private func runAnalysis() {
        Task { await appState.runAnalysis() }
    }
}
