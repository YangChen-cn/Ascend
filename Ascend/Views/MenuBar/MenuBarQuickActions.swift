import AppKit
import SwiftUI

struct MenuBarQuickActions: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var isScanning = false

    var body: some View {
        HStack(spacing: 8) {
            // 次要按钮：巡察
            Button(action: scanNow) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .rotationEffect(.degrees(isScanning ? 360 : 0))
                        .animation(
                            isScanning ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                            value: isScanning
                        )
                    Text(isScanning ? "巡察中…" : "巡察")
                }
                .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .tint(MenuBarPalette.secondaryInk(colorScheme))
            .controlSize(.small)
            .disabled(isScanning || appState.isAnalyzing)

            // 唯一主要按钮：悟道
            Button(action: runAnalysis) {
                HStack(spacing: 4) {
                    if appState.isAnalyzing {
                        ProgressView()
                            .controlSize(.mini)
                        Text("悟道中…")
                    } else {
                        Image(systemName: "sparkles")
                        Text("悟道")
                    }
                }
                .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(MenuBarPalette.gold(colorScheme))
            .controlSize(.small)
            .disabled(appState.isAnalyzing)

            Spacer()

            // 选项与设置菜单 (···)
            Menu {
                Button(action: openMainWindow) {
                    Label("打开知境录", systemImage: "macwindow")
                }

                Divider()

                TargetedSettingsButton(section: .general) {
                    Label("设置 (⌘,)", systemImage: "gearshape")
                }

                TargetedSettingsButton(section: .about) {
                    Label("关于知境录", systemImage: "info.circle")
                }

                if !appState.endpointProfiles.isEmpty {
                    Menu("AI 模型", systemImage: "cpu") {
                        ForEach(appState.endpointProfiles) { profile in
                            if profile.cachedModelIDs.isEmpty {
                                Button(profile.selectedModelID.isEmpty ? "\(profile.name) · 未选择" : "\(profile.name) · \(profile.selectedModelID)") {}
                                    .disabled(true)
                            } else {
                                Section(profile.name) {
                                    ForEach(profile.cachedModelIDs, id: \.self) { modelID in
                                        Button {
                                            appState.selectModel(profileID: profile.id, modelID: modelID)
                                        } label: {
                                            if appState.activeEndpointID == profile.id && profile.selectedModelID == modelID {
                                                Label(modelID, systemImage: "checkmark")
                                            } else {
                                                Text(modelID)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Button(action: { appState.isCollecting.toggle() }) {
                    Label(
                        appState.isCollecting ? "暂停自动采集" : "开启自动采集",
                        systemImage: appState.isCollecting ? "pause.circle" : "play.circle"
                    )
                }

                Divider()

                Button("退出知境录", systemImage: "power", role: .destructive, action: quit)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(MenuBarPalette.secondaryInk(colorScheme))
                    .frame(width: 24, height: 24)
                    .contentShape(.rect)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func scanNow() {
        isScanning = true
        Task {
            try? await appState.scanSources()
            isScanning = false
        }
    }

    private func runAnalysis() {
        Task {
            await appState.runAnalysis()
        }
    }

    private func openMainWindow() {
        openWindow(id: "main")
        dismiss()
        Task { @MainActor in
            await Task.yield()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
