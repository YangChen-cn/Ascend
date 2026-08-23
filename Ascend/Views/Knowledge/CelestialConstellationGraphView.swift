import SwiftUI

struct CelestialConstellationGraphView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    let domainName: String
    let nodes: [KnowledgeNode]
    let selectedNodeID: UUID?
    let score: (KnowledgeNode) -> Double
    var onSelectNode: ((KnowledgeNode?) -> Void)? = nil
    var onOpenNode: ((KnowledgeNode) -> Void)? = nil

    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var basePanOffset: CGSize = .zero
    @State private var draggedNodeID: UUID?
    @State private var nodeDragStartPos: CGPoint? = nil
    @State private var customNodePositions: [UUID: CGPoint] = [:]
    @State private var hoveredNodeID: UUID?
    @State private var lastViewportSize: CGSize = .zero

    private var nodeIDs: Set<UUID> { Set(nodes.map(\.id)) }

    private var domainEdges: [KnowledgeEdge] {
        appState.knowledgeEdges.filter { edge in
            nodeIDs.contains(edge.sourceNodeID) && nodeIDs.contains(edge.targetNodeID)
        }
    }

    private var nodeDegrees: [UUID: Int] {
        domainEdges.reduce(into: [UUID: Int]()) { result, edge in
            result[edge.sourceNodeID, default: 0] += 1
            result[edge.targetNodeID, default: 0] += 1
        }
    }

    // MARK: - 状态计算 (Default / Hover / Selected)

    private var selectedLineageSet: Set<UUID> {
        guard let selectedID = selectedNodeID else { return [] }
        return appState.lineageHighlightSet(for: selectedID)
    }

    private var hoverDirectNeighbors: Set<UUID> {
        guard let hoveredID = hoveredNodeID else { return [] }
        var set: Set<UUID> = [hoveredID]
        for edge in domainEdges {
            if edge.sourceNodeID == hoveredID {
                set.insert(edge.targetNodeID)
            } else if edge.targetNodeID == hoveredID {
                set.insert(edge.sourceNodeID)
            }
        }
        return set
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let basePositions = computeRelaxedPositions(in: size)
            let currentPositions = resolvedPositions(base: basePositions)
            let bounds = ConstellationViewportMath.contentBounds(positions: Array(currentPositions.values))

            // 批量预计算掌握度与拓扑状态
            let compositeScores = appState.currentCompositeByNodeID()
            let topologyStatusMap = Dictionary(uniqueKeysWithValues: nodes.map { node in
                (node.id, appState.topologyEngine.status(for: node.id, edges: appState.knowledgeEdges, masteryByNodeID: compositeScores))
            })

            ZStack {
                // 1. 典雅背景 (点击空白区域取消选中)
                celestialBackground(in: size)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelectNode?(nil)
                    }

                // 2. 可平移与缩放的星宿层
                ZStack {
                    // 同心天球星轨环（长方形自适应椭圆星轨）
                    celestialOrbitRings(in: size)

                    // 灵脉连线层（Glowing Ley-Lines）
                    leyLinesLayer(positions: currentPositions)

                    // 星宿节点层（Stellar Nodes）
                    stellarNodesLayer(positions: currentPositions, statusMap: topologyStatusMap)
                }
                .scaleEffect(zoomScale)
                .offset(panOffset)
                .contentShape(Rectangle())
                .gesture(
                    draggedNodeID == nil
                        ? DragGesture()
                            .onChanged { value in
                                panOffset = CGSize(
                                    width: basePanOffset.width + value.translation.width,
                                    height: basePanOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                let clamped = ConstellationViewportMath.clampedPanOffset(
                                    proposedOffset: panOffset,
                                    zoomScale: zoomScale,
                                    contentBounds: bounds,
                                    viewportSize: size
                                )
                                panOffset = clamped
                                basePanOffset = clamped
                            }
                        : nil
                )

                // 3. 顶部与底部悬浮控制台
                graphOverlayControls(in: size, bounds: bounds)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AscendTheme.border(for: colorScheme), lineWidth: 1)
            }
            .onKeyPress(.escape) {
                if selectedNodeID != nil {
                    onSelectNode?(nil)
                    return .handled
                }
                return .ignored
            }
            .onChange(of: size) { oldSize, newSize in
                guard newSize.width > 0, newSize.height > 0 else { return }
                if oldSize.width > 0 && oldSize.height > 0 {
                    // 视口尺寸变化（如 Inspector 展开/关闭），重新 clamp panOffset，避免视野跳变与大块空白
                    let clamped = ConstellationViewportMath.clampedPanOffset(
                        proposedOffset: panOffset,
                        zoomScale: zoomScale,
                        contentBounds: bounds,
                        viewportSize: newSize
                    )
                    withAnimation(.easeInOut(duration: 0.2)) {
                        panOffset = clamped
                        basePanOffset = clamped
                    }
                }
                lastViewportSize = newSize
            }
        }
        .frame(minHeight: 480, idealHeight: 540, maxHeight: 640)
    }

    // MARK: - 1. 典雅背景

    private func celestialBackground(in size: CGSize) -> some View {
        ZStack {
            if colorScheme == .dark {
                // 深色模式：太虚玄渊
                RadialGradient(
                    colors: [Color(red: 0.05, green: 0.08, blue: 0.10), Color(red: 0.02, green: 0.03, blue: 0.04)],
                    center: .center,
                    startRadius: 20,
                    endRadius: max(size.width, size.height) * 0.85
                )
            } else {
                // 浅色模式：素绢温玉白与淡金宣纸微渐变
                LinearGradient(
                    colors: [
                        Color(red: 0.985, green: 0.980, blue: 0.965),
                        Color(red: 0.965, green: 0.955, blue: 0.935)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // 微弱星尘
            Canvas { context, canvasSize in
                let count = 50
                for i in 0..<count {
                    let pseudoRandomX = Double((i * 157 + 73) % Int(max(1, canvasSize.width)))
                    let pseudoRandomY = Double((i * 283 + 109) % Int(max(1, canvasSize.height)))
                    let radius: CGFloat = (i % 4 == 0) ? 1.5 : 0.8
                    let opacity: Double = colorScheme == .dark
                        ? ((i % 3 == 0) ? 0.35 : 0.15)
                        : ((i % 3 == 0) ? 0.20 : 0.08)
                    let point = CGPoint(x: pseudoRandomX, y: pseudoRandomY)
                    var path = Path()
                    path.addEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
                    context.fill(path, with: .color(colorScheme == .dark ? AscendTheme.cobalt.opacity(opacity) : AscendTheme.gold.opacity(opacity)))
                }
            }
        }
    }

    // MARK: - 同心天球星轨环

    private func celestialOrbitRings(in size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let rx = max(160, (size.width - 180) / 2)
        let ry = max(110, (size.height - 130) / 2)

        return ZStack {
            Ellipse()
                .stroke(
                    colorScheme == .dark
                        ? AscendTheme.cobalt.opacity(0.14)
                        : AscendTheme.jade.opacity(0.12),
                    style: StrokeStyle(lineWidth: 1.0, dash: [4, 8])
                )
                .frame(width: rx * 2 * 0.48, height: ry * 2 * 0.48)
                .position(center)

            Ellipse()
                .stroke(
                    colorScheme == .dark
                        ? AscendTheme.gold.opacity(0.12)
                        : AscendTheme.gold.opacity(0.14),
                    style: StrokeStyle(lineWidth: 1.0, dash: [6, 10])
                )
                .frame(width: rx * 2 * 0.82, height: ry * 2 * 0.82)
                .position(center)

            Ellipse()
                .stroke(
                    colorScheme == .dark
                        ? AscendTheme.cobalt.opacity(0.08)
                        : AscendTheme.border(for: colorScheme),
                    style: StrokeStyle(lineWidth: 0.8, dash: [3, 12])
                )
                .frame(width: rx * 2 * 0.98, height: ry * 2 * 0.98)
                .position(center)
        }
        .allowsHitTesting(false)
    }

    // MARK: - 2. 灵脉连线层

    private func leyLinesLayer(positions: [UUID: CGPoint]) -> some View {
        let selectedID = selectedNodeID
        let hoveredID = hoveredNodeID
        let lineage = selectedLineageSet
        let hoverNeighbors = hoverDirectNeighbors

        return Canvas { context, _ in
            for edge in domainEdges {
                guard let sourcePos = positions[edge.sourceNodeID],
                      let targetPos = positions[edge.targetNodeID] else { continue }

                let isPrereq = edge.relationRawValue == "prerequisite"
                let isDirectHovered = hoveredID != nil && (edge.sourceNodeID == hoveredID || edge.targetNodeID == hoveredID)
                let isLineageEdge = selectedID != nil && lineage.contains(edge.sourceNodeID) && lineage.contains(edge.targetNodeID)

                let isHighlighted: Bool = {
                    if selectedID != nil {
                        return isLineageEdge
                    } else if hoveredID != nil {
                        return isDirectHovered
                    } else {
                        return false
                    }
                }()

                let baseAlpha: Double = {
                    if selectedID != nil {
                        return isLineageEdge ? 1.0 : 0.12
                    } else if hoveredID != nil {
                        return isDirectHovered ? 0.90 : 0.20
                    } else {
                        return isPrereq ? 0.40 : 0.25
                    }
                }()

                var path = Path()
                path.move(to: sourcePos)

                let midX = (sourcePos.x + targetPos.x) / 2
                let midY = (sourcePos.y + targetPos.y) / 2
                let dx = targetPos.x - sourcePos.x
                let dy = targetPos.y - sourcePos.y
                let normalOffset = CGPoint(x: -dy * 0.08, y: dx * 0.08)
                let controlPoint = CGPoint(x: midX + normalOffset.x, y: midY + normalOffset.y)

                path.addQuadCurve(to: targetPos, control: controlPoint)

                let lineWidth: CGFloat = isHighlighted ? (isPrereq ? 2.8 : 2.2) : (isPrereq ? 1.6 : 1.1)

                let lineColor1 = isPrereq
                    ? (isHighlighted ? AscendTheme.gold : AscendTheme.jade.opacity(baseAlpha))
                    : (isHighlighted ? AscendTheme.gold : (colorScheme == .dark ? AscendTheme.cobalt.opacity(baseAlpha) : AscendTheme.deepJade.opacity(baseAlpha)))

                let lineColor2 = isPrereq
                    ? (isHighlighted ? AscendTheme.jade : AscendTheme.gold.opacity(baseAlpha))
                    : (isHighlighted ? AscendTheme.jade : AscendTheme.gold.opacity(baseAlpha))

                if isPrereq {
                    context.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [lineColor1, lineColor2]),
                            startPoint: sourcePos,
                            endPoint: targetPos
                        ),
                        lineWidth: lineWidth
                    )

                    // 绘制先导方向指示箭头
                    let t: CGFloat = 0.70
                    let invT = 1.0 - t
                    let arrowX = invT * invT * sourcePos.x + 2 * invT * t * controlPoint.x + t * t * targetPos.x
                    let arrowY = invT * invT * sourcePos.y + 2 * invT * t * controlPoint.y + t * t * targetPos.y

                    let tangentX = 2 * invT * (controlPoint.x - sourcePos.x) + 2 * t * (targetPos.x - controlPoint.x)
                    let tangentY = 2 * invT * (controlPoint.y - sourcePos.y) + 2 * t * (targetPos.y - controlPoint.y)
                    let angle = atan2(tangentY, tangentX)

                    let arrowSize: CGFloat = isHighlighted ? 8.0 : 5.5
                    var arrowPath = Path()
                    arrowPath.move(to: CGPoint(x: arrowX + cos(angle) * arrowSize, y: arrowY + sin(angle) * arrowSize))
                    arrowPath.addLine(to: CGPoint(x: arrowX + cos(angle + 2.5) * arrowSize, y: arrowY + sin(angle + 2.5) * arrowSize))
                    arrowPath.addLine(to: CGPoint(x: arrowX + cos(angle - 2.5) * arrowSize, y: arrowY + sin(angle - 2.5) * arrowSize))
                    arrowPath.closeSubpath()

                    context.fill(arrowPath, with: .color(lineColor2))
                } else {
                    context.stroke(
                        path,
                        with: .linearGradient(
                            Gradient(colors: [lineColor1, lineColor2]),
                            startPoint: sourcePos,
                            endPoint: targetPos
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, dash: [4, 4])
                    )
                }
            }
        }
    }

    // MARK: - 3. 星宿节点层

    @ViewBuilder
    private func stellarNodesLayer(positions: [UUID: CGPoint], statusMap: [UUID: NodeTopologyStatus]) -> some View {
        let selectedID = selectedNodeID
        let hoveredID = hoveredNodeID
        let lineage = selectedLineageSet
        let hoverNeighbors = hoverDirectNeighbors

        ForEach(nodes, id: \.id) { node in
            if let pos = positions[node.id] {
                let nodeScore = score(node)
                let isSelected = selectedID == node.id
                let isHovered = hoveredID == node.id

                let nodeOpacity: Double = {
                    if let selectedID {
                        return (isSelected || lineage.contains(node.id)) ? 1.0 : 0.50
                    } else if hoveredID != nil {
                        return (isHovered || hoverNeighbors.contains(node.id)) ? 1.0 : 0.75
                    } else {
                        return 1.0
                    }
                }()

                let nodeStatus = statusMap[node.id] ?? .progressing

                CelestialStarNodeView(
                    node: node,
                    score: nodeScore,
                    topologyStatus: nodeStatus,
                    isSelected: isSelected,
                    isHovered: isHovered,
                    opacity: nodeOpacity,
                    onSelect: {
                        if selectedNodeID == node.id {
                            onSelectNode?(nil) // 再次点击同一节点取消选择
                        } else {
                            onSelectNode?(node) // 单击选中
                        }
                    },
                    onOpen: {
                        onSelectNode?(node)
                        onOpenNode?(node) // 双击打开详情，不自动修改视口 zoom/pan
                    }
                )
                .position(pos)
                .gesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            if nodeDragStartPos == nil {
                                nodeDragStartPos = customNodePositions[node.id] ?? pos
                            }
                            draggedNodeID = node.id
                            if let start = nodeDragStartPos {
                                let newPos = CGPoint(
                                    x: start.x + value.translation.width / zoomScale,
                                    y: start.y + value.translation.height / zoomScale
                                )
                                customNodePositions[node.id] = newPos
                            }
                        }
                        .onEnded { _ in
                            draggedNodeID = nil
                            nodeDragStartPos = nil
                        }
                )
                .onHover { hovering in
                    hoveredNodeID = hovering ? node.id : (hoveredNodeID == node.id ? nil : hoveredNodeID)
                }
            }
        }
    }

    // MARK: - 4. 悬浮控制层

    private func graphOverlayControls(in size: CGSize, bounds: CGRect) -> some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(AscendTheme.gold)
                        Text("\(domainName) · 星图拓扑")
                            .font(.system(.subheadline, design: .serif))
                            .bold()
                    }
                    Text(selectedNodeID != nil ? "已聚焦知脉 · 点击空白/Esc 取消选择" : "单击选中高亮知脉 · 双击开启修道研习 · 拖拽自由排布星宿")
                        .font(.system(.caption2, design: .serif))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay {
                    Capsule().strokeBorder(AscendTheme.border(for: colorScheme), lineWidth: 0.8)
                }

                Spacer()

                HStack(spacing: 4) {
                    Button(action: { zoomBy(delta: 0.15, size: size, bounds: bounds) }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .help("放大星图 (围绕视口中心)")

                    Button(action: { zoomBy(delta: -0.15, size: size, bounds: bounds) }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .help("缩小星图 (围绕视口中心)")

                    Button(action: { fitView(size: size, bounds: bounds) }) {
                        Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .help("自适应居中视野 (保持自定义排布)")

                    Menu {
                        Button("自适应居中视野") {
                            fitView(size: size, bounds: bounds)
                        }
                        Button("重置星宿拖拽排布", role: .destructive) {
                            resetLayout(size: size)
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption)
                    }
                    .menuStyle(.borderedButton)
                    .help("视野复位与排布重置")
                }
                .padding(6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay {
                    Capsule().strokeBorder(AscendTheme.border(for: colorScheme), lineWidth: 0.8)
                }
            }
            .padding(12)

            Spacer()

            // 底部图例与统计
            HStack {
                HStack(spacing: 8) {
                    ConstellationLegendBadge(title: "化用通达", subtitle: "80+", style: .gold)
                    ConstellationLegendBadge(title: "融会", subtitle: "60–79", style: .jade)
                    ConstellationLegendBadge(title: "通晓", subtitle: "40–59", style: .cobalt)
                    ConstellationLegendBadge(title: "入门", subtitle: "20–39", style: .neutral)
                    ConstellationLegendBadge(title: "初窥", subtitle: "<20", style: .cinnabar)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay {
                    Capsule().strokeBorder(AscendTheme.border(for: colorScheme), lineWidth: 0.8)
                }

                Spacer()

                Text("\(nodes.count) 个星宿 · \(domainEdges.count) 条灵脉")
                    .font(.system(.caption2, design: .serif))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay {
                        Capsule().strokeBorder(AscendTheme.border(for: colorScheme), lineWidth: 0.8)
                    }
            }
            .padding(12)
        }
    }

    private func zoomBy(delta: CGFloat, size: CGSize, bounds: CGRect) {
        let oldScale = zoomScale
        let newScale = min(ConstellationViewportMath.maxZoomScale, max(ConstellationViewportMath.minZoomScale, oldScale + delta))
        let proposedOffset = ConstellationViewportMath.zoomTransform(
            oldScale: oldScale,
            newScale: newScale,
            currentOffset: panOffset
        )
        let clamped = ConstellationViewportMath.clampedPanOffset(
            proposedOffset: proposedOffset,
            zoomScale: newScale,
            contentBounds: bounds,
            viewportSize: size
        )
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            zoomScale = newScale
            panOffset = clamped
            basePanOffset = clamped
        }
    }

    private func fitView(size: CGSize, bounds: CGRect) {
        let (scale, offset) = ConstellationViewportMath.fitTransform(
            contentBounds: bounds,
            viewportSize: size
        )
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            zoomScale = scale
            panOffset = offset
            basePanOffset = offset
        }
    }

    private func resetLayout(size: CGSize) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            customNodePositions.removeAll()
            zoomScale = 1.0
            panOffset = .zero
            basePanOffset = .zero
            onSelectNode?(nil)
        }
    }

    // MARK: - 5. 智能防重叠力导向布局算法

    private func computeRelaxedPositions(in size: CGSize) -> [UUID: CGPoint] {
        guard !nodes.isEmpty else { return [:] }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        if nodes.count == 1 {
            return [nodes[0].id: center]
        }

        let roundedW = Int(size.width.rounded())
        let roundedH = Int(size.height.rounded())
        let nodeKey = nodes.map(\.id.uuidString).sorted().joined(separator: ",")
        let topologyKey = domainEdges
            .map { "\($0.sourceNodeID.uuidString)->\($0.targetNodeID.uuidString):\($0.relationRawValue)" }
            .sorted()
            .joined(separator: ";")
        let layoutKey = "\(domainName):\(nodeKey):\(topologyKey):\(roundedW)x\(roundedH)"
        if let cached = GraphLayoutCache.positions(for: layoutKey) {
            return cached
        }

        let sorted = nodes.sorted { lhs, rhs in
            let degL = nodeDegrees[lhs.id, default: 0]
            let degR = nodeDegrees[rhs.id, default: 0]
            if degL != degR { return degL > degR }
            if lhs.name != rhs.name {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        var posMap: [UUID: CGPoint] = [:]
        let count = sorted.count

        let rx = max(160, (size.width - 180) / 2)
        let ry = max(110, (size.height - 130) / 2)

        posMap[sorted[0].id] = center

        let remaining = Array(sorted.dropFirst())

        for (index, node) in remaining.enumerated() {
            let tier: Double
            let angleOffset: Double

            if count <= 4 {
                tier = 0.72
                angleOffset = 0
            } else if index < 3 {
                tier = 0.48
                angleOffset = 0
            } else if index < 7 {
                tier = 0.82
                angleOffset = 0.28
            } else {
                tier = 0.98
                angleOffset = 0.56
            }

            let angleBase = (Double(index) / Double(remaining.count)) * 2 * .pi - (.pi / 2)
            let angle = angleBase + angleOffset

            let x = center.x + CGFloat(cos(angle)) * rx * CGFloat(tier)
            let y = center.y + CGFloat(sin(angle)) * ry * CGFloat(tier)
            posMap[node.id] = CGPoint(x: x, y: y)
        }

        let minCollisionDist: CGFloat = 135.0
        var currentMap = posMap

        for _ in 0..<35 {
            for i in 0..<sorted.count {
                let idA = sorted[i].id
                guard var pA = currentMap[idA] else { continue }

                for j in (i + 1)..<sorted.count {
                    let idB = sorted[j].id
                    guard var pB = currentMap[idB] else { continue }

                    let dx = pB.x - pA.x
                    let dy = pB.y - pA.y
                    let dist = max(1.0, sqrt(dx * dx + dy * dy))

                    if dist < minCollisionDist {
                        let overlap = (minCollisionDist - dist) * 0.5
                        let nx = dx / dist
                        let ny = dy / dist

                        if idA != sorted[0].id {
                            pA.x -= nx * overlap * 0.6
                            pA.y -= ny * overlap * 0.6
                        }
                        if idB != sorted[0].id {
                            pB.x += nx * overlap * 0.6
                            pB.y += ny * overlap * 0.6
                        }

                        currentMap[idA] = pA
                        currentMap[idB] = pB
                    }
                }
            }
        }

        let marginX: CGFloat = 78
        let marginYTop: CGFloat = 58
        let marginYBottom: CGFloat = 62
        for (id, pt) in currentMap {
            let clampedX = min(max(pt.x, marginX), size.width - marginX)
            let clampedY = min(max(pt.y, marginYTop), size.height - marginYBottom)
            currentMap[id] = CGPoint(x: clampedX, y: clampedY)
        }

        GraphLayoutCache.setPositions(currentMap, for: layoutKey)
        return currentMap
    }

    private func resolvedPositions(base: [UUID: CGPoint]) -> [UUID: CGPoint] {
        var result = base
        for (id, customPos) in customNodePositions {
            result[id] = customPos
        }
        return result
    }
}

// MARK: - 星宿节点子视图

private struct CelestialStarNodeView: View {
    @Environment(\.colorScheme) private var colorScheme
    let node: KnowledgeNode
    let score: Double
    let topologyStatus: NodeTopologyStatus
    let isSelected: Bool
    let isHovered: Bool
    let opacity: Double
    let onSelect: () -> Void
    let onOpen: () -> Void

    private var stage: MasteryStage {
        MasteryStage.stage(for: score)
    }

    private var isBlocked: Bool {
        if case .blocked = topologyStatus { return true }
        return false
    }

    private var isReadyToLearn: Bool {
        if case .readyToLearn = topologyStatus { return true }
        return false
    }

    private var masteryColor: Color {
        switch stage {
        case .mastered, .connected: AscendTheme.gold
        case .integrated: AscendTheme.jade
        case .proficient: AscendTheme.cobalt
        case .advancing: AscendTheme.amber
        case .entry: AscendTheme.cinnabar
        }
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 5) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(masteryColor.opacity(colorScheme == .dark ? 0.35 : 0.22))
                            .frame(width: 48, height: 48)
                            .blur(radius: 5)
                    }

                    if isReadyToLearn && !isSelected {
                        Circle()
                            .strokeBorder(
                                AngularGradient(
                                    gradient: Gradient(colors: [AscendTheme.gold, AscendTheme.jade, AscendTheme.gold]),
                                    center: .center
                                ),
                                lineWidth: 1.5
                            )
                            .frame(width: 36, height: 36)
                            .shadow(color: AscendTheme.gold.opacity(0.3), radius: 4)
                    }

                    if isBlocked {
                        Circle()
                            .stroke(AscendTheme.cinnabar.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                            .frame(width: 34, height: 34)
                    }

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    colorScheme == .dark ? Color.white.opacity(0.85) : masteryColor.opacity(0.2),
                                    masteryColor,
                                    colorScheme == .dark ? masteryColor.opacity(0.7) : masteryColor.opacity(0.9)
                                ],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: 16
                            )
                        )
                        .frame(width: isSelected ? 26 : (isHovered ? 24 : 20),
                               height: isSelected ? 26 : (isHovered ? 24 : 20))
                        .shadow(
                            color: masteryColor.opacity(isSelected ? 0.85 : (isHovered ? 0.6 : 0.35)),
                            radius: isSelected ? 8 : 4
                        )

                    if isBlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.white)
                            .shadow(color: Color.black.opacity(0.6), radius: 2)
                    } else if stage == .mastered || stage == .connected {
                        Image(systemName: "sparkle")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                }
                .frame(width: 48, height: 48)

                Text(node.name)
                    .font(.system(size: isSelected ? 12 : 11, weight: isSelected ? .bold : .medium, design: .serif))
                    .foregroundStyle(
                        isSelected
                            ? (colorScheme == .dark ? Color.white : Color.black)
                            : (colorScheme == .dark ? Color.white.opacity(0.9) : Color.primary.opacity(0.85))
                    )
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        isSelected
                            ? (colorScheme == .dark ? Color.black.opacity(0.7) : Color.white.opacity(0.85))
                            : Color.clear
                    )
                    .clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
        .opacity(opacity)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                onOpen()
            }
        )
    }
}

// MARK: - 境界图例徽章

private struct ConstellationLegendBadge: View {
    let title: String
    let subtitle: String
    let style: BadgeStyle

    enum BadgeStyle {
        case gold, jade, cobalt, neutral, cinnabar
        var color: Color {
            switch self {
            case .gold: AscendTheme.gold
            case .jade: AscendTheme.jade
            case .cobalt: AscendTheme.cobalt
            case .neutral: AscendTheme.amber
            case .cinnabar: AscendTheme.cinnabar
            }
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(style.color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 10, weight: .medium, design: .serif))
            Text(subtitle)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

@MainActor
private enum GraphLayoutCache {
    private static var cache: [String: [UUID: CGPoint]] = [:]
    static func positions(for key: String) -> [UUID: CGPoint]? {
        cache[key]
    }
    static func setPositions(_ positions: [UUID: CGPoint], for key: String) {
        if cache.count > 50 { cache.removeAll() }
        cache[key] = positions
    }
}
