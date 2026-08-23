import AppKit
import SwiftUI

struct MenuBarQuickActions: View {
    @Environment(AppState.self) private var appState

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
            .tint(AscendTheme.gold)
            .controlSize(.small)
            .disabled(appState.isAnalyzing)

            Spacer()

            // 选项与设置菜单 (···)
            Menu {
                TargetedSettingsButton(section: .general) {
                    Label("设置 (⌘,)", systemImage: "gearshape")
                }

                Divider()

                Button("退出知境录", systemImage: "power", role: .destructive, action: quit)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(.rect)
            }
            .menuStyle(.borderlessButton)
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

    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
