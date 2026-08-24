import AppKit
import SwiftUI

enum ScrollExportTheme: String, CaseIterable, Identifiable {
    case xuanqing = "玄青墨韵"
    case sujuan = "素绢云宣"

    var id: String { rawValue }

    var isDark: Bool {
        self == .xuanqing
    }
}

struct CelestialScrollExportSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTheme: ScrollExportTheme = .xuanqing
    @State private var toastMessage: String? = nil
    @State private var isExporting = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "scroll.fill")
                            .foregroundStyle(AscendTheme.gold)
                        Text("修真研习画卷")
                            .font(.system(.headline, design: .serif))
                            .bold()
                    }
                    Text("将道行境界、五维全真雷达图与已证灵脉凝结为画卷导出分享")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Picker("画卷风貌", selection: $selectedTheme) {
                    ForEach(ScrollExportTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Button("关闭", action: { dismiss() })
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.regularMaterial)

            Divider()

            // 画卷预览区（支持平滑缩放与滚动）
            ScrollView([.horizontal, .vertical]) {
                CelestialStudyScrollView(isDark: selectedTheme.isDark)
                    .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(selectedTheme.isDark ? Color.black.opacity(0.85) : Color.gray.opacity(0.15))

            Divider()

            // 底部操作栏
            HStack {
                if let toast = toastMessage {
                    Label(toast, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AscendTheme.jade)
                        .transition(.opacity)
                }

                Spacer()

                Button(action: copyToClipboard) {
                    Label("复制到剪贴板", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(isExporting)

                Button(action: savePNG) {
                    Label("保存为高清图片", systemImage: "square.and.arrow.down.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(AscendTheme.gold)
                .disabled(isExporting)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
        .frame(minWidth: 780, minHeight: 680)
        .animation(.easeInOut(duration: 0.2), value: toastMessage)
    }

    // MARK: - 导出操作

    @MainActor
    private func renderImage() -> NSImage? {
        let view = CelestialStudyScrollView(isDark: selectedTheme.isDark)
            .environment(appState)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0 // 2x Retina 清晰度
        return renderer.nsImage
    }

    @MainActor
    private func copyToClipboard() {
        guard let nsImage = renderImage() else {
            showToast("渲染画卷失败")
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([nsImage])
        showToast("已成功复制画卷至剪贴板，可直接在微信/Slack等处粘贴！")
    }

    @MainActor
    private func savePNG() {
        guard let nsImage = renderImage(),
              let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            showToast("生成 PNG 图像失败")
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmm"
        let timestamp = dateFormatter.string(from: .now)
        panel.nameFieldStringValue = "知境录-修真研习画卷-\(timestamp).png"
        panel.title = "保存修真研习画卷"

        if panel.runModal() == .OK, let targetURL = panel.url {
            do {
                try pngData.write(to: targetURL)
                showToast("画卷已成功保存至 \(targetURL.lastPathComponent)")
            } catch {
                showToast("保存失败：\(error.localizedDescription)")
            }
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(3.5))
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }
}
