import SwiftUI

struct CelestialConstellationGraphView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    let domainName: String
    let nodes: [KnowledgeNode]
    let selectedNodeID: UUID?
    let score: (KnowledgeNode) -> Double
    let onSelectNode: (KnowledgeNode) -> Void

    @State private var zoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var draggedNodeID: UUID?
    @State private var customNodePositions: [UUID: CGPoint] = [:]
    @State private var hoveredNodeID: UUID?

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

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let basePositions = computeRelaxedPositions(in: size)
            let currentPositions = resolvedPositions(base: basePositions)

            ZStack {
                // 1. 典雅背景（浅色模式下为素绢温玉宣纸色，深色模式下为太虚玄渊）
                celestialBackground(in: size)

                // 2. 可平移与缩放的星宿层
                ZStack {
                    // 同心天球星轨环（Celestial Orbit Rings）
                    celestialOrbitRings(in: size)

                    // 灵脉连线层（Glowing Ley-Lines）
                    leyLinesLayer(positions: currentPositions)

                    // 星宿节点层（Stellar Nodes）
                    stellarNodesLayer(positions: currentPositions)
                }
                .scaleEffect(zoomScale)
                .offset(panOffset)
                .contentShape(Rectangle())
                .gesture(
                    draggedNodeID == nil
                        ? DragGesture()
                            .onChanged { value in
                                panOffset = CGSize(
                                    width: panOffset.width + value.translation.width * 0.5,
                                    height: panOffset.height + value.translation.height * 0.5
                                )
                            }
                        : nil
                )

                // 3. 顶部与底部悬浮控制台
                graphOverlayControls(in: size)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AscendTheme.border(for: colorScheme), lineWidth: 1)
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
                let count = 45
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
                    context.fill(path, with: .color((i % 2 == 0 ? AscendTheme.gold : AscendTheme.jade).opacity(opacity)))
                }
            }
        }
    }

    private func celestialOrbitRings(in size: CGSize) -> some View {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let minDim = min(size.width, size.height)
        let ringColor = colorScheme == .dark ? AscendTheme.gold : Color(red: 0.65, green: 0.55, blue: 0.35)

        return ZStack {
            // 外轨
            Circle()
                .strokeBorder(
                    ringColor.opacity(colorScheme == .dark ? 0.15 : 0.12),
                    style: StrokeStyle(lineWidth: 0.9, dash: [6, 8])
                )
                .frame(width: minDim * 0.92, height: minDim * 0.92)
                .position(center)

            // 中轨
            Circle()
                .strokeBorder(
                    ringColor.opacity(colorScheme == .dark ? 0.18 : 0.15),
                    style: StrokeStyle(lineWidth: 0.9, dash: [4, 6])
                )
                .frame(width: minDim * 0.62, height: minDim * 0.62)
                .position(center)

            // 内轨
            Circle()
                .strokeBorder(
                    (colorScheme == .dark ? AscendTheme.jade : AscendTheme.deepJade).opacity(colorScheme == .dark ? 0.15 : 0.12),
                    style: StrokeStyle(lineWidth: 0.8, dash: [3, 5])
                )
                .frame(width: minDim * 0.32, height: minDim * 0.32)
                .position(center)
        }
    }

    // MARK: - 2. 灵脉连线

    private func leyLinesLayer(positions: [UUID: CGPoint]) -> some View {
        Canvas { context, _ in
            for edge in domainEdges {
                guard let sourcePos = positions[edge.sourceNodeID],
                      let targetPos = positions[edge.targetNodeID] else { continue }

                let isHighlighted = (hoveredNodeID == edge.sourceNodeID || hoveredNodeID == edge.targetNodeID ||
                                     selectedNodeID == edge.sourceNodeID || selectedNodeID == edge.targetNodeID)
                let isDimmed = (hoveredNodeID != nil || selectedNodeID != nil) && !isHighlighted

                var path = Path()
                path.move(to: sourcePos)

                let midX = (sourcePos.x + targetPos.x) / 2
                let midY = (sourcePos.y + targetPos.y) / 2
                let dx = targetPos.x - sourcePos.x
                let dy = targetPos.y - sourcePos.y
                let normalOffset = CGPoint(x: -dy * 0.08, y: dx * 0.08)
                let controlPoint = CGPoint(x: midX + normalOffset.x, y: midY + normalOffset.y)

                path.addQuadCurve(to: targetPos, control: controlPoint)

                let baseAlpha = isDimmed ? 0.06 : (isHighlighted ? 0.90 : (colorScheme == .dark ? 0.45 : 0.35))
                let lineWidth: CGFloat = isHighlighted ? 2.6 : 1.4

                let lineColor1 = colorScheme == .dark
                    ? (isHighlighted ? AscendTheme.gold : AscendTheme.cobalt.opacity(baseAlpha))
                    : (isHighlighted ? AscendTheme.gold : AscendTheme.deepJade.opacity(baseAlpha))

                let lineColor2 = colorScheme == .dark
                    ? (isHighlighted ? AscendTheme.jade : AscendTheme.gold.opacity(baseAlpha))
                    : (isHighlighted ? AscendTheme.jade : AscendTheme.gold.opacity(baseAlpha))

                context.stroke(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [lineColor1, lineColor2]),
                        startPoint: sourcePos,
                        endPoint: targetPos
                    ),
                    lineWidth: lineWidth
                )
            }
        }
    }

    // MARK: - 3. 星宿节点层

    private func stellarNodesLayer(positions: [UUID: CGPoint]) -> some View {
        ForEach(nodes) { node in
            if let pos = positions[node.id] {
                let nodeScore = score(node)
                let isSelected = selectedNodeID == node.id
                let isHovered = hoveredNodeID == node.id
                let isDimmed = (hoveredNodeID != nil || selectedNodeID != nil) && !isSelected && !isHovered && !isConnectedToFocus(node.id)

                CelestialStarNodeView(
                    node: node,
                    score: nodeScore,
                    isSelected: isSelected,
                    isHovered: isHovered,
                    isDimmed: isDimmed,
                    action: { onSelectNode(node) }
                )
                .position(pos)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            draggedNodeID = node.id
                            let newPos = CGPoint(
                                x: pos.x + value.translation.width / zoomScale,
                                y: pos.y + value.translation.height / zoomScale
                            )
                            customNodePositions[node.id] = newPos
                        }
                        .onEnded { _ in
                            draggedNodeID = nil
                        }
                )
                .onHover { hovering in
                    hoveredNodeID = hovering ? node.id : (hoveredNodeID == node.id ? nil : hoveredNodeID)
                }
            }
        }
    }

    private func isConnectedToFocus(_ nodeID: UUID) -> Bool {
        guard let focusID = hoveredNodeID ?? selectedNodeID else { return false }
        return domainEdges.contains { edge in
            (edge.sourceNodeID == focusID && edge.targetNodeID == nodeID) ||
            (edge.targetNodeID == focusID && edge.sourceNodeID == nodeID)
        }
    }

    // MARK: - 4. 悬浮控制层

    private func graphOverlayControls(in size: CGSize) -> some View {
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
                    Text("拖拽可排布星宿 · 双指缩放可探索深空知脉")
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
                    Button(action: { zoomScale = min(2.5, zoomScale + 0.2) }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .help("放大星图")

                    Button(action: { zoomScale = max(0.5, zoomScale - 0.2) }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .help("缩小星图")

                    Button(action: resetView) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .help("复位星图视野")
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

            // 底部图例
            HStack {
                HStack(spacing: 8) {
                    CelestialBadge(title: "化用通达", subtitle: "80+", style: .gold)
                    CelestialBadge(title: "融会", subtitle: "60–79", style: .jade)
                    CelestialBadge(title: "通晓", subtitle: "40–59", style: .astral)
                    CelestialBadge(title: "入门", subtitle: "20–39", style: .neutral)
                    CelestialBadge(title: "初窥", subtitle: "<20", style: .cinnabar)
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

    private func resetView() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            zoomScale = 1.0
            panOffset = .zero
            customNodePositions.removeAll()
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

        // 基础半轴尺寸
        let rx = max(140, (size.width - 200) / 2)
        let ry = max(115, (size.height - 180) / 2)

        // 核心主星在中心
        posMap[sorted[0].id] = center

        let remaining = Array(sorted.dropFirst())

        for (index, node) in remaining.enumerated() {
            let tier: Double
            let angleOffset: Double

            if count <= 4 {
                tier = 0.65
                angleOffset = 0
            } else if index < 4 {
                tier = 0.48
                angleOffset = 0
            } else if index < 9 {
                tier = 0.80
                angleOffset = 0.38
            } else {
                tier = 1.05
                angleOffset = 0.72
            }

            let angleBase = (Double(index) / Double(remaining.count)) * 2 * .pi - (.pi / 2)
            let angle = angleBase + angleOffset

            let x = center.x + CGFloat(cos(angle)) * rx * CGFloat(tier)
            let y = center.y + CGFloat(sin(angle)) * ry * CGFloat(tier)
            posMap[node.id] = CGPoint(x: x, y: y)
        }

        // 35 轮力导向排斥，确保舒适的标签间距
        let minCollisionDist: CGFloat = 145.0
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

// MARK: - 单个星宿节点视图

private struct CelestialStarNodeView: View {
    @Environment(\.colorScheme) private var colorScheme
    let node: KnowledgeNode
    let score: Double
    let isSelected: Bool
    let isHovered: Bool
    let isDimmed: Bool
    let action: () -> Void

    private var stage: MasteryStage {
        MasteryStage.stage(for: score)
    }

    private var nodeThemeColor: Color {
        switch stage {
        case .mastered, .connected: AscendTheme.gold
        case .integrated: AscendTheme.jade
        case .proficient: AscendTheme.cobalt
        case .advancing: Color(red: 0.20, green: 0.65, blue: 0.85)
        case .entry: AscendTheme.amber
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    // 外层气场光晕（Aura Glow）
                    Circle()
                        .fill(nodeThemeColor.opacity(isSelected ? 0.40 : (isHovered ? 0.30 : 0.18)))
                        .frame(width: nodeSize + 22, height: nodeSize + 22)
                        .blur(radius: isSelected ? 6 : 3.5)

                    // 选中时的旋转星轨金环
                    if isSelected {
                        Circle()
                            .strokeBorder(
                                AscendTheme.goldGradient,
                                style: StrokeStyle(lineWidth: 1.8, dash: [4, 3])
                            )
                            .frame(width: nodeSize + 14, height: nodeSize + 14)
                    }

                    // 星宿本体核心
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    nodeThemeColor,
                                    nodeThemeColor.opacity(0.85),
                                    colorScheme == .dark ? Color.black.opacity(0.6) : Color.white.opacity(0.3)
                                ],
                                center: .center,
                                startRadius: 2,
                                endRadius: nodeSize / 2
                            )
                        )
                        .frame(width: nodeSize, height: nodeSize)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    isSelected ? Color.white : (colorScheme == .dark ? Color.white.opacity(0.4) : Color.white.opacity(0.8)),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        }
                        .shadow(color: nodeThemeColor.opacity(0.6), radius: isSelected ? 6 : 3)

                    // 核心掌握度数字
                    Text("\(Int(score.rounded()))")
                        .font(.system(size: max(10, nodeSize * 0.36), weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.white)
                }

                // 节点名称玉牌（浅色模式为温润羊脂白胶囊，深色模式为黑玉胶囊）
                HStack(spacing: 5) {
                    Circle()
                        .fill(nodeThemeColor)
                        .frame(width: 5.5, height: 5.5)

                    Text(node.name)
                        .font(.system(size: isSelected ? 12 : 11, weight: isSelected ? .bold : .semibold, design: .serif))
                        .foregroundStyle(colorScheme == .dark ? Color.white : Color(red: 0.12, green: 0.10, blue: 0.08))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(
                    Capsule()
                        .fill(
                            colorScheme == .dark
                                ? (isSelected ? Color(red: 0.15, green: 0.12, blue: 0.05) : Color(red: 0.08, green: 0.10, blue: 0.13))
                                : (isSelected ? Color(red: 1.0, green: 0.97, blue: 0.90) : Color.white)
                        )
                )
                .overlay {
                    Capsule()
                        .strokeBorder(
                            isSelected ? AscendTheme.gold : AscendTheme.border(for: colorScheme),
                            lineWidth: isSelected ? 1.4 : 0.8
                        )
                }
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.08),
                    radius: isSelected ? 5 : 3,
                    y: 1.5
                )
                .frame(maxWidth: 135)
            }
            .opacity(isDimmed ? 0.20 : 1.0)
            .scaleEffect(isSelected ? 1.15 : (isHovered ? 1.08 : 1.0))
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isSelected)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isHovered)
            .animation(.easeInOut(duration: 0.2), value: isDimmed)
        }
        .buttonStyle(.plain)
    }

    private var nodeSize: CGFloat {
        if score >= 80 { return 36 }
        if score >= 60 { return 32 }
        if score >= 40 { return 28 }
        return 24
    }
}

// MARK: - 星图力导向布局内存缓存

@MainActor
private enum GraphLayoutCache {
    private static var cache: [String: [UUID: CGPoint]] = [:]

    static func positions(for key: String) -> [UUID: CGPoint]? {
        cache[key]
    }

    static func setPositions(_ positions: [UUID: CGPoint], for key: String) {
        if cache.count > 50 {
            cache.removeAll()
        }
        cache[key] = positions
    }
}

