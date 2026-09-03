import AppKit
import SwiftUI

/// Unified sheet used by every Markdown-note preview entry point.
struct MarkdownNotePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let fileLocator: String
    let excerpt: String
    let timestamp: Date

    @State private var rawContent = ""
    @State private var isLoading = true
    @State private var fileExists = true
    @State private var isCopied = false

    init(activity: ActivityEvent) {
        title = activity.title
        fileLocator = activity.sourceLocator
        excerpt = activity.excerpt
        timestamp = activity.timestamp
    }

    private var fileURL: URL? {
        ReviewActivityLocator.markdownFileURL(from: fileLocator)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    metadataCard

                    if isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.small)
                            Text("正在加载研习笔记…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 160)
                    } else {
                        markdownContentSection
                    }
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                colorScheme == .dark
                    ? Color(red: 0.04, green: 0.06, blue: 0.08)
                    : Color(red: 0.985, green: 0.980, blue: 0.970)
            )

            Divider()
            footerBar
        }
        .frame(minWidth: 740, idealWidth: 860, minHeight: 560, idealHeight: 720)
        .task {
            await loadContent()
        }
    }

    private var headerBar: some View {
        SheetHeaderView(
            title,
            subtitle: fileURL?.path,
            systemImage: "doc.text.fill"
        ) {
            Button("关闭", systemImage: "xmark.circle.fill") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.escape, modifiers: [])
        }
    }

    private var metadataCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("记录时间")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(timestamp, format: .dateTime.year().month().day().hour().minute())
                    .font(.system(.caption, design: .rounded))
                    .bold()
            }

            Divider()
                .frame(height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text("文件状态")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    Circle()
                        .fill(fileExists ? AscendTheme.jade : AscendTheme.amber)
                        .frame(width: 6, height: 6)
                    Text(fileExists ? "本地源文件就绪" : "已使用快照摘要")
                        .font(.caption)
                        .foregroundStyle(fileExists ? AscendTheme.jade : AscendTheme.amber)
                }
            }

            Spacer()

            if fileURL != nil, fileExists {
                HStack(spacing: 8) {
                    Button(action: revealInFinder) {
                        Label("在访达中显示", systemImage: "folder")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)

                    Button(action: openInDefaultApp) {
                        Label("用默认编辑器打开", systemImage: "arrow.up.forward.app")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AscendTheme.gold)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(AscendTheme.border(for: colorScheme), lineWidth: 0.8)
        }
    }

    private var markdownContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("笔记正文")
                    .font(.subheadline)
                    .bold()

                Spacer()

                Button(action: copyContent) {
                    Label(
                        isCopied ? "已复制" : "复制全文",
                        systemImage: isCopied ? "checkmark" : "doc.on.doc"
                    )
                    .font(.caption2)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

            Group {
                if rawContent.isEmpty {
                    Text("暂无笔记内容")
                        .foregroundStyle(.secondary)
                } else {
                    LocalMarkdownDocumentView(
                        source: rawContent,
                        baseURL: fileExists ? fileURL?.deletingLastPathComponent() : nil
                    )
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.03) : Color.white)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(AscendTheme.border(for: colorScheme), lineWidth: 0.8)
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.04),
                radius: 6,
                y: 2
            )
        }
    }

    private var footerBar: some View {
        HStack {
            if let url = fileURL {
                Text(url.lastPathComponent)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("完成", action: { dismiss() })
                .buttonStyle(.borderedProminent)
                .tint(AscendTheme.jade)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private func loadContent() async {
        isLoading = true
        let locator = fileLocator
        let fallbackExcerpt = excerpt

        let result = await Task.detached(priority: .userInitiated) { () -> (String, Bool) in
            if let url = ReviewActivityLocator.markdownFileURL(from: locator),
               FileManager.default.fileExists(atPath: url.path),
               let data = try? Data(contentsOf: url),
               let content = String(data: data, encoding: .utf8) {
                return (content, true)
            }
            return (fallbackExcerpt, false)
        }.value

        guard !Task.isCancelled else { return }
        rawContent = result.0
        fileExists = result.1
        isLoading = false
    }

    private func revealInFinder() {
        guard let url = fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func openInDefaultApp() {
        guard let url = fileURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func copyContent() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(rawContent, forType: .string)
        isCopied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            isCopied = false
        }
    }
}
