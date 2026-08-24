import SwiftUI

struct ConceptLineagePathwayView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    let nodeID: UUID

    private var node: KnowledgeNode? {
        appState.node(for: nodeID)
    }

    private var prerequisites: [KnowledgeNode] {
        appState.prerequisites(for: nodeID)
    }

    private var downstream: [KnowledgeNode] {
        appState.downstreamConcepts(for: nodeID)
    }

    private var semanticEdges: [KnowledgeEdge] {
        appState.knowledgeEdges.filter { edge in
            (edge.sourceNodeID == nodeID || edge.targetNodeID == nodeID) &&
            edge.relation != .prerequisite
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // 模块标题
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(AscendTheme.gold)
                Text("修道脉络 · 先导与知脉")
                    .font(.subheadline)
                    .bold()
                Spacer()
            }

            // 1. 先导前置依赖
            prerequisiteSection

            // 2. 后继解锁概念
            downstreamSection

            // 3. 语义关联网
            semanticRelationsSection
        }
        .padding(16)
        .panelCard()
    }

    // MARK: - 1. 先导前置区

    private var prerequisiteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.left.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AscendTheme.amber)
                Text("先导依赖（需达到融会 60 分以破境解锁）")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            if prerequisites.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "sparkle")
                        .font(.caption2)
                        .foregroundStyle(AscendTheme.jade)
                    Text("本概念暂无前置先导依赖，可作为筑基之学随时研习")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(prerequisites) { prereq in
                        prerequisiteRow(for: prereq)
                    }
                }
            }
        }
    }

    private func prerequisiteRow(for prereq: KnowledgeNode) -> some View {
        let score = appState.currentComposite(for: prereq.id)
        let isSatisfied = score >= 60.0

        return Button(action: { appState.selectedKnowledgeNodeID = prereq.id }) {
            HStack(spacing: 10) {
                Circle()
                    .fill(isSatisfied ? AscendTheme.jade : AscendTheme.cinnabar)
                    .frame(width: 7, height: 7)

                Text(prereq.name)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color(red: 0.12, green: 0.10, blue: 0.08))

                Spacer()

                HStack(spacing: 6) {
                    if isSatisfied {
                        Label("已融会", systemImage: "checkmark.seal.fill")
                            .font(.caption2.bold())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(AscendTheme.jade.opacity(0.15))
                            .foregroundStyle(AscendTheme.jade)
                            .clipShape(Capsule())
                            .help("当前掌握 \(Int(score.rounded())) / 60")
                    } else {
                        Label("未达融会", systemImage: "lock.fill")
                            .font(.caption2.bold())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(AscendTheme.cinnabar.opacity(0.15))
                            .foregroundStyle(AscendTheme.cinnabar)
                            .clipShape(Capsule())
                            .help("当前掌握 \(Int(score.rounded())) / 60，达到融会后解锁下游推荐")
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSatisfied ? AscendTheme.jade.opacity(0.25) : AscendTheme.cinnabar.opacity(0.3), lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 2. 后继解锁区

    private var downstreamSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AscendTheme.jade)
                Text("后继通达（掌握当前概念后解锁）")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            if downstream.isEmpty {
                Text("暂无依赖本知识点的后继概念，AI 将在后续研习中智能推演下一境")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(downstream) { nextNode in
                        let status = appState.topologyStatus(for: nextNode.id)
                        let isReady: Bool = {
                            if case .readyToLearn = status { return true }
                            return false
                        }()

                        Button(action: { appState.selectedKnowledgeNodeID = nextNode.id }) {
                            HStack(spacing: 5) {
                                if isReady {
                                    Image(systemName: "sparkles")
                                        .font(.caption2)
                                        .foregroundStyle(AscendTheme.jade)
                                } else {
                                    Image(systemName: "lock.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Text(nextNode.name)
                                    .font(.caption)
                                    .fontWeight(.medium)

                                Text(isReady ? "可修" : "待前置")
                                    .font(.system(size: 9).bold())
                                    .foregroundStyle(isReady ? AscendTheme.jade : .secondary)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4.5)
                            .background(
                                Capsule()
                                    .fill(isReady ? AscendTheme.jade.opacity(0.12) : Color.primary.opacity(0.04))
                            )
                            .overlay {
                                Capsule()
                                    .strokeBorder(isReady ? AscendTheme.jade.opacity(0.5) : AscendTheme.border(for: colorScheme), lineWidth: 0.8)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 3. 语义关联网

    private var semanticRelationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !semanticEdges.isEmpty {
                Divider()
                    .overlay(AscendTheme.gold.opacity(0.15))

                HStack(spacing: 6) {
                    Image(systemName: "network")
                        .font(.caption)
                        .foregroundStyle(AscendTheme.cobalt)
                    Text("相生相克 · 语义关联网")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

                FlowLayout(spacing: 8) {
                    ForEach(semanticEdges) { edge in
                        let targetID = (edge.sourceNodeID == nodeID) ? edge.targetNodeID : edge.sourceNodeID
                        if let relatedNode = appState.node(for: targetID) {
                            Button(action: { appState.selectedKnowledgeNodeID = relatedNode.id }) {
                                HStack(spacing: 5) {
                                    Text(edge.relation.title)
                                        .font(.system(size: 9).bold())
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1.5)
                                        .background(AscendTheme.cobalt.opacity(0.15))
                                        .foregroundStyle(AscendTheme.cobalt)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))

                                    Text(relatedNode.name)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.primary.opacity(0.03))
                                .clipShape(Capsule())
                                .overlay {
                                    Capsule().strokeBorder(AscendTheme.border(for: colorScheme), lineWidth: 0.8)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 轻量流式布局容器

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        height = y + rowHeight
        return CGSize(width: width, height: max(height, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}
