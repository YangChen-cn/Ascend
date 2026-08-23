import AppKit
import SwiftUI

struct MenuBarQuickActions: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    @State private var isScanning = false

    var body: some View {
        HStack(spacing: 8) {
            // 巡察按钮
            Button(action: scanNow) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .rotationEffect(.degrees(isScanning ? 360 : 0))
                        .animation(isScanning ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isScanning)
                    Text(isScanning ? "巡察中…" : "巡察")
                }
                .font(.system(size: 11, design: .serif))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isScanning || appState.isAnalyzing)

            // 悟道分析按钮（分析中直接在按钮内部展示进度 Spinner）
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
                .font(.system(size: 11, design: .serif))
            }
            .buttonStyle(.borderedProminent)
            .tint(AscendTheme.gold)
            .controlSize(.small)
            .disabled(appState.isAnalyzing)

            Spacer()

            // 设置与 AI 接口菜单
            Menu {
                if !appState.endpointProfiles.isEmpty {
                    Section("AI 灵犀模型") {
                        ForEach(appState.endpointProfiles) { profile in
                            ForEach(profile.cachedModelIDs, id: \.self) { modelID in
                                Button(modelID) {
                                    appState.selectModel(profileID: profile.id, modelID: modelID)
                                }
                            }
                        }
                    }
                    Divider()
                }

                TargetedSettingsButton(section: .general) {
                    Label("设置 (⌘,)", systemImage: "gearshape")
                }

                Divider()

                Button("退出知境录", systemImage: "power", role: .destructive, action: quit)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 20)

            // 打开知境录主窗口
            Button(action: openMainWindow) {
                Image(systemName: "macwindow")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("打开知境录主窗口")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
