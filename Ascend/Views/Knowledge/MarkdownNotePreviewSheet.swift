import AppKit
import SwiftUI

struct MarkdownNotePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let fileLocator: String
    let excerpt: String
    let timestamp: Date

    @State private var rawContent: String = ""
    @State private var parsedBlocks: [MarkdownBlock] = []
    @State private var isLoading: Bool = true
    @State private var fileExists: Bool = true
    @State private var isCopied: Bool = false

    private var fileURL: URL? {
        let cleanPath = fileLocator.components(separatedBy: "#").first ?? fileLocator
        let url = URL(fileURLWithPath: cleanPath)
        return url.pathExtension.lowercased() == "md" || FileManager.default.fileExists(atPath: cleanPath) ? url : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部导航与操作条
            headerBar

            Divider()

            // 正文内容区域（纯净阅读，绝不掺杂审计片段）
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 文件元数据卡片
                    metadataCard

                    // 笔记 Markdown 结构化正文
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
            .background(colorScheme == .dark ? Color(red: 0.04, green: 0.06, blue: 0.08) : Color(red: 0.985, green: 0.980, blue: 0.970))

            Divider()

            // 底部操作栏
            footerBar
        }
        .frame(minWidth: 740, idealWidth: 860, minHeight: 560, idealHeight: 720)
        .task {
            await loadAndParseContentAsync()
        }
    }

    // MARK: - 顶部导航条

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

    // MARK: - 文件元数据

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

    // MARK: - 笔记正文 Markdown 渲染

    private var markdownContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("笔记正文")
                    .font(.subheadline)
                    .bold()

                Spacer()

                Button(action: copyContent) {
                    Label(isCopied ? "已复制" : "复制全文", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }

            if parsedBlocks.isEmpty {
                Text(rawContent.isEmpty ? "暂无笔记内容" : rawContent)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(parsedBlocks) { block in
                        renderMarkdownBlock(block)
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
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.04), radius: 6, y: 2)
            }
        }
    }

    @ViewBuilder
    private func renderMarkdownBlock(_ block: MarkdownBlock) -> some View {
        switch block.kind {
        case .h1:
            Text(LocalizedStringKey(block.text))
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(AscendTheme.gold)
                .padding(.top, 8)

        case .h2:
            Text(LocalizedStringKey(block.text))
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(colorScheme == .dark ? Color.white : Color.primary)
                .padding(.top, 6)

        case .h3:
            Text(LocalizedStringKey(block.text))
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundStyle(AscendTheme.jade)
                .padding(.top, 4)

        case .h4:
            Text(LocalizedStringKey(block.text))
                .font(.system(size: 14, weight: .bold, design: .serif))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

        case .paragraph:
            Text(LocalizedStringKey(block.text))
                .font(.system(size: 13.5, design: .serif))
                .lineSpacing(4.5)
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.9) : Color.primary)

        case .codeBlock(let language):
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if !language.isEmpty {
                        Text(language.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(AscendTheme.gold)
                    }
                    Spacer()
                    Button(action: { copySpecificText(block.text) }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("复制代码块")
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    Text(block.text)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(colorScheme == .dark ? Color(red: 0.5, green: 0.9, blue: 0.6) : Color(red: 0.1, green: 0.35, blue: 0.2))
                        .textSelection(.enabled)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(colorScheme == .dark ? Color.black.opacity(0.55) : Color(red: 0.94, green: 0.95, blue: 0.96))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.8)
            }

        case .table(let headers, let alignments, let rows):
            MarkdownTableView(headers: headers, alignments: alignments, rows: rows)

        case .quote:
            HStack(spacing: 8) {
                Rectangle()
                    .fill(AscendTheme.gold)
                    .frame(width: 3.5)
                Text(LocalizedStringKey(block.text))
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

        case .bullet:
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AscendTheme.jade)
                Text(LocalizedStringKey(block.text))
                    .font(.system(size: 13.5, design: .serif))
                    .lineSpacing(3)
            }

        case .orderedList(let number):
            HStack(alignment: .top, spacing: 6) {
                Text("\(number).")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AscendTheme.gold)
                    .frame(minWidth: 18, alignment: .trailing)
                Text(LocalizedStringKey(block.text))
                    .font(.system(size: 13.5, design: .serif))
                    .lineSpacing(3)
            }

        case .taskItem(let isDone):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: isDone ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13))
                    .foregroundStyle(isDone ? AscendTheme.jade : .secondary)
                Text(LocalizedStringKey(block.text))
                    .font(.system(size: 13.5, design: .serif))
                    .strikethrough(isDone, color: .secondary)
                    .foregroundStyle(isDone ? .secondary : (colorScheme == .dark ? Color.white : Color.primary))
            }

        case .divider:
            Divider()
                .overlay(AscendTheme.border(for: colorScheme))
                .padding(.vertical, 6)
        }
    }

    // MARK: - 底部操作栏

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

    // MARK: - 异步非阻塞加载与解析

    private func loadAndParseContentAsync() async {
        isLoading = true
        let locator = fileLocator
        let exc = excerpt

        let result = await Task.detached(priority: .userInitiated) { () -> (String, Bool) in
            let cleanPath = locator.components(separatedBy: "#").first ?? locator
            let url = URL(fileURLWithPath: cleanPath)
            if FileManager.default.fileExists(atPath: url.path),
               let data = try? Data(contentsOf: url),
               let content = String(data: data, encoding: .utf8) {
                return (content, true)
            } else {
                return (exc, false)
            }
        }.value

        let text = result.0
        let exists = result.1

        let blocks = await Task.detached(priority: .userInitiated) { () -> [MarkdownBlock] in
            Self.parseMarkdown(text)
        }.value

        rawContent = text
        parsedBlocks = blocks
        fileExists = exists
        isLoading = false
    }

    private nonisolated static func parseMarkdown(_ content: String) -> [MarkdownBlock] {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var blocks: [MarkdownBlock] = []
        var inCodeBlock = false
        var codeLang = ""
        var codeAccumulator: [String] = []

        var index = 0
        let total = lines.count

        while index < total {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 1. 代码块围栏
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    blocks.append(MarkdownBlock(kind: .codeBlock(language: codeLang), text: codeAccumulator.joined(separator: "\n")))
                    codeAccumulator.removeAll()
                    inCodeBlock = false
                    codeLang = ""
                } else {
                    inCodeBlock = true
                    codeLang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                index += 1
                continue
            }

            if inCodeBlock {
                codeAccumulator.append(line)
                index += 1
                continue
            }

            if trimmed.isEmpty {
                index += 1
                continue
            }

            // 2. 表格检查 (GFM Table)
            if trimmed.contains("|") && index + 1 < total {
                let nextTrimmed = lines[index + 1].trimmingCharacters(in: .whitespaces)
                if isTableSeparator(nextTrimmed) {
                    let headerCells = splitTableRow(trimmed)
                    let alignments = parseTableAlignments(nextTrimmed)
                    var tableRows: [[String]] = []
                    index += 2

                    while index < total {
                        let rowLine = lines[index].trimmingCharacters(in: .whitespaces)
                        if rowLine.isEmpty || !rowLine.contains("|") {
                            break
                        }
                        let cells = splitTableRow(rowLine)
                        tableRows.append(cells)
                        index += 1
                    }

                    blocks.append(MarkdownBlock(kind: .table(headers: headerCells, alignments: alignments, rows: tableRows), text: ""))
                    continue
                }
            }

            // 3. 任务清单
            if trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("* [ ] ") {
                blocks.append(MarkdownBlock(kind: .taskItem(isDone: false), text: String(trimmed.dropFirst(6))))
                index += 1
                continue
            }
            if trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") || trimmed.hasPrefix("* [x] ") || trimmed.hasPrefix("* [X] ") {
                blocks.append(MarkdownBlock(kind: .taskItem(isDone: true), text: String(trimmed.dropFirst(6))))
                index += 1
                continue
            }

            // 4. 标题
            if trimmed.hasPrefix("# ") {
                blocks.append(MarkdownBlock(kind: .h1, text: String(trimmed.dropFirst(2))))
                index += 1
                continue
            }
            if trimmed.hasPrefix("## ") {
                blocks.append(MarkdownBlock(kind: .h2, text: String(trimmed.dropFirst(3))))
                index += 1
                continue
            }
            if trimmed.hasPrefix("### ") {
                blocks.append(MarkdownBlock(kind: .h3, text: String(trimmed.dropFirst(4))))
                index += 1
                continue
            }
            if trimmed.hasPrefix("#### ") {
                blocks.append(MarkdownBlock(kind: .h4, text: String(trimmed.dropFirst(5))))
                index += 1
                continue
            }

            // 5. 引用
            if trimmed.hasPrefix("> ") {
                blocks.append(MarkdownBlock(kind: .quote, text: String(trimmed.dropFirst(2))))
                index += 1
                continue
            }

            // 6. 有序列表 (如 1. 2.)
            if let dotIndex = trimmed.firstIndex(of: "."),
               dotIndex > trimmed.startIndex,
               let num = Int(trimmed[trimmed.startIndex..<dotIndex]) {
                let rest = trimmed[trimmed.index(after: dotIndex)...].trimmingCharacters(in: .whitespaces)
                blocks.append(MarkdownBlock(kind: .orderedList(number: "\(num)"), text: rest))
                index += 1
                continue
            }

            // 7. 无序列表
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                blocks.append(MarkdownBlock(kind: .bullet, text: String(trimmed.dropFirst(2))))
                index += 1
                continue
            }

            // 8. 分割线
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(MarkdownBlock(kind: .divider, text: ""))
                index += 1
                continue
            }

            // 9. 普通段落
            blocks.append(MarkdownBlock(kind: .paragraph, text: line))
            index += 1
        }

        if inCodeBlock && !codeAccumulator.isEmpty {
            blocks.append(MarkdownBlock(kind: .codeBlock(language: codeLang), text: codeAccumulator.joined(separator: "\n")))
        }

        return blocks
    }

    private nonisolated static func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") && trimmed.contains("-") else { return false }
        let chars = Set(trimmed)
        return chars.isSubset(of: Set("|-: \t"))
    }

    private nonisolated static func splitTableRow(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }
        return trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private nonisolated static func parseTableAlignments(_ separatorLine: String) -> [TextAlignment] {
        let cells = splitTableRow(separatorLine)
        return cells.map { cell in
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            let hasLeft = trimmed.hasPrefix(":")
            let hasRight = trimmed.hasSuffix(":")
            if hasLeft && hasRight {
                return .center
            } else if hasRight {
                return .trailing
            } else {
                return .leading
            }
        }
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

    private func copySpecificText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Markdown 表格渲染组件

private struct MarkdownTableView: View {
    let headers: [String]
    let alignments: [TextAlignment]
    let rows: [[String]]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                // 表头
                GridRow {
                    ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                        let alignment = index < alignments.count ? alignments[index] : .leading
                        Text(LocalizedStringKey(header))
                            .font(.system(size: 12.5, weight: .bold, design: .serif))
                            .foregroundStyle(AscendTheme.gold)
                            .frame(maxWidth: .infinity, alignment: frameAlignment(for: alignment))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                colorScheme == .dark
                                    ? AscendTheme.gold.opacity(0.15)
                                    : Color(red: 0.94, green: 0.92, blue: 0.88)
                            )
                            .border(AscendTheme.border(for: colorScheme), width: 0.5)
                    }
                }

                // 数据行
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    GridRow {
                        ForEach(0..<headers.count, id: \.self) { colIndex in
                            let cellText = colIndex < row.count ? row[colIndex] : ""
                            let alignment = colIndex < alignments.count ? alignments[colIndex] : .leading
                            Text(LocalizedStringKey(cellText))
                                .font(.system(size: 12, design: .default))
                                .frame(maxWidth: .infinity, alignment: frameAlignment(for: alignment))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    rowIndex % 2 == 1
                                        ? (colorScheme == .dark ? Color.white.opacity(0.025) : Color.primary.opacity(0.025))
                                        : Color.clear
                                )
                                .border(AscendTheme.border(for: colorScheme), width: 0.5)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(AscendTheme.border(for: colorScheme), lineWidth: 1)
            }
        }
        .padding(.vertical, 4)
    }

    private func frameAlignment(for textAlignment: TextAlignment) -> Alignment {
        switch textAlignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}

// MARK: - Markdown 数据模型

enum MarkdownBlockKind: Equatable, Sendable {
    case h1
    case h2
    case h3
    case h4
    case paragraph
    case codeBlock(language: String)
    case table(headers: [String], alignments: [TextAlignment], rows: [[String]])
    case quote
    case bullet
    case orderedList(number: String)
    case taskItem(isDone: Bool)
    case divider
}

struct MarkdownBlock: Identifiable, Sendable {
    let id = UUID()
    let kind: MarkdownBlockKind
    let text: String
}
