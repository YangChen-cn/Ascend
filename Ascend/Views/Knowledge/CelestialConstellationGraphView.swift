import SwiftUI

struct CelestialConstellationGraphView: View {
    @Environment(\.colorScheme) private var colorScheme

    let snapshot: ConstellationDomainRenderSnapshot
    let selectedNodeID: UUID?
    var onSelectNode: ((UUID?) -> Void)?
    var onOpenNode: ((UUID) -> Void)?
    var onPersistPosition: ((UUID, CGPoint) -> Void)?
    var onResetPersistedLayout: (() -> Void)?

    @State private var zoomScale: CGFloat = 1
    @State private var userPanOffset: CGSize = .zero
    @State private var panGestureStart: CGSize?
    @State private var draggedNodeID: UUID?
    @State private var nodeDragStartPosition: CGPoint?
    @State private var positionOverrides: [UUID: CGPoint] = [:]
    @State private var geometryOverrides: [UUID: ConstellationEdgeGeometry] = [:]
    @State private var hoveredNodeID: UUID?
    @State private var usesCanonicalLayout = false
    @State private var localContentBounds: CGRect?

    var body: some View {
        GeometryReader { proxy in
            let viewportSize = proxy.size
            let transform = viewportTransform(in: viewportSize)

            ZStack {
                CelestialGraphBackground(colorScheme: colorScheme)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelectNode?(nil) }

                graphContent(transform: transform)
                    .frame(width: snapshot.layout.canvasSize.width, height: snapshot.layout.canvasSize.height)
                    .scaleEffect(x: transform.xScale, y: transform.yScale)
                    .position(
                        x: viewportSize.width / 2 + transform.offset.width,
                        y: viewportSize.height / 2 + transform.offset.height
                    )
                    .contentShape(Rectangle())
                    .gesture(panGesture(transform: transform))

                controls(viewportSize: viewportSize)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AscendTheme.border(for: colorScheme), lineWidth: 1)
            }
            .onKeyPress(.escape) {
                guard selectedNodeID != nil else { return .ignored }
                onSelectNode?(nil)
                return .handled
            }
        }
        .frame(minHeight: 480, idealHeight: 540, maxHeight: 640)
        .onChange(of: snapshot.layout.identity) {
            let validNodeIDs = Set(snapshot.nodes.map(\.id))
            positionOverrides = positionOverrides.reduce(into: [:]) { result, entry in
                guard validNodeIDs.contains(entry.key) else { return }
                result[entry.key] = clampedNodePosition(entry.value)
            }
            geometryOverrides.removeAll(keepingCapacity: true)
            for nodeID in positionOverrides.keys { updateIncidentGeometry(nodeID: nodeID) }
            localContentBounds = positionOverrides.isEmpty
                ? nil
                : ConstellationViewportMath.renderContentBounds(
                    positions: snapshot.nodes.map { position(for: $0.id) }
                )
            draggedNodeID = nil
            nodeDragStartPosition = nil
        }
    }

    @ViewBuilder
    private func graphContent(transform: ConstellationViewportMath.ViewportTransform) -> some View {
        ZStack {
            CelestialOrbitRings(canvasSize: snapshot.layout.canvasSize, colorScheme: colorScheme)

            EquatableView(content: ConstellationBaseLeyLinesLayer(
                edges: snapshot.edges,
                baseGeometryByID: snapshot.edgeGeometryByID,
                geometryOverrides: geometryOverrides,
                drawsPrerequisites: true,
                isDark: colorScheme == .dark
            ))
            .opacity(selectedNodeID == nil ? (hoveredNodeID == nil ? 1 : 0.50) : 0.30)

            EquatableView(content: ConstellationBaseLeyLinesLayer(
                edges: snapshot.edges,
                baseGeometryByID: snapshot.edgeGeometryByID,
                geometryOverrides: geometryOverrides,
                drawsPrerequisites: false,
                isDark: colorScheme == .dark
            ))
            .opacity(selectedNodeID == nil ? (hoveredNodeID == nil ? 1 : 0.80) : 0.48)

            EquatableView(content: ConstellationHighlightLeyLinesLayer(
                highlightedEdgeIDs: highlightedEdgeIDs,
                edges: snapshot.edges,
                baseGeometryByID: snapshot.edgeGeometryByID,
                geometryOverrides: geometryOverrides
            ))

            ForEach(snapshot.nodes) { node in
                let isSelected = selectedNodeID == node.id
                let isHovered = hoveredNodeID == node.id
                CelestialStarNodeView(
                    node: node,
                    isSelected: isSelected,
                    isHovered: isHovered,
                    opacity: nodeOpacity(node.id),
                    onSelect: { onSelectNode?(node.id) },
                    onOpen: { onOpenNode?(node.id) }
                )
                .scaleEffect(
                    x: transform.nodeScale / max(0.001, transform.xScale),
                    y: transform.nodeScale / max(0.001, transform.yScale)
                )
                .position(position(for: node.id))
                .gesture(nodeDragGesture(nodeID: node.id, transform: transform))
                .onHover { hovering in
                    let next = hovering ? node.id : (hoveredNodeID == node.id ? nil : hoveredNodeID)
                    if next != hoveredNodeID { hoveredNodeID = next }
                }
            }
        }
        .frame(width: snapshot.layout.canvasSize.width, height: snapshot.layout.canvasSize.height)
    }

    private var highlightedEdgeIDs: Set<UUID> {
        if let selectedNodeID {
            return snapshot.lineageEdgeIDsByNodeID[selectedNodeID] ?? []
        }
        if let hoveredNodeID {
            return snapshot.incidentEdgeIDsByNodeID[hoveredNodeID] ?? []
        }
        return []
    }

    private func nodeOpacity(_ nodeID: UUID) -> Double {
        if let selectedNodeID {
            return (snapshot.lineageNodeIDsByNodeID[selectedNodeID] ?? [selectedNodeID]).contains(nodeID) ? 1 : 0.25
        }
        if let hoveredNodeID {
            let neighbors = snapshot.neighborNodeIDsByNodeID[hoveredNodeID] ?? []
            return nodeID == hoveredNodeID || neighbors.contains(nodeID) ? 1 : 0.50
        }
        return 1
    }

    private func position(for nodeID: UUID) -> CGPoint {
        positionOverrides[nodeID] ?? basePositions[nodeID] ?? .zero
    }

    private var basePositions: [UUID: CGPoint] {
        usesCanonicalLayout ? snapshot.layout.canonicalPositions : snapshot.layout.positions
    }

    private var contentBounds: CGRect {
        localContentBounds ?? (usesCanonicalLayout ? snapshot.layout.canonicalContentBounds : snapshot.layout.contentBounds)
    }

    private func viewportTransform(in viewportSize: CGSize) -> ConstellationViewportMath.ViewportTransform {
        ConstellationViewportMath.viewportTransform(
            logicalCanvasSize: snapshot.layout.canvasSize,
            contentBounds: contentBounds,
            viewportSize: viewportSize,
            userZoomScale: zoomScale,
            proposedUserPanOffset: userPanOffset
        )
    }

    private func panGesture(transform: ConstellationViewportMath.ViewportTransform) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard draggedNodeID == nil else { return }
                if panGestureStart == nil { panGestureStart = transform.userPanOffset }
                guard let start = panGestureStart else { return }
                userPanOffset = CGSize(
                    width: start.width + value.translation.width,
                    height: start.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard draggedNodeID == nil else { return }
                userPanOffset = transform.userPanOffset
                panGestureStart = nil
            }
    }

    private func nodeDragGesture(
        nodeID: UUID,
        transform: ConstellationViewportMath.ViewportTransform
    ) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                if nodeDragStartPosition == nil {
                    nodeDragStartPosition = position(for: nodeID)
                    draggedNodeID = nodeID
                }
                guard let start = nodeDragStartPosition else { return }
                let point = clampedNodePosition(CGPoint(
                    x: start.x + value.translation.width / max(0.001, transform.xScale),
                    y: start.y + value.translation.height / max(0.001, transform.yScale)
                ))
                positionOverrides[nodeID] = point
                updateIncidentGeometry(nodeID: nodeID)
            }
            .onEnded { _ in
                if let point = positionOverrides[nodeID] {
                    onPersistPosition?(nodeID, point)
                    localContentBounds = ConstellationViewportMath.renderContentBounds(
                        positions: snapshot.nodes.map { position(for: $0.id) }
                    )
                }
                draggedNodeID = nil
                nodeDragStartPosition = nil
            }
    }

    private func clampedNodePosition(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 42), snapshot.layout.canvasSize.width - 42),
            y: min(max(point.y, 42), snapshot.layout.canvasSize.height - 42)
        )
    }

    private func updateIncidentGeometry(nodeID: UUID) {
        for edgeID in snapshot.incidentEdgeIDsByNodeID[nodeID] ?? [] {
            guard let edge = snapshot.edgeByID[edgeID],
                  let geometry = ConstellationEdgeGeometry.make(
                    edge: edge,
                    positions: [
                        edge.sourceNodeID: position(for: edge.sourceNodeID),
                        edge.targetNodeID: position(for: edge.targetNodeID)
                    ]
                  ) else { continue }
            geometryOverrides[edgeID] = geometry
        }
    }

    private func controls(viewportSize: CGSize) -> some View {
        VStack {
            ViewThatFits(in: .horizontal) {
                HStack {
                    graphTitle
                    Spacer(minLength: 12)
                    controlButtons(viewportSize: viewportSize)
                }

                VStack(alignment: .leading, spacing: 8) {
                    graphTitle
                    HStack {
                        Spacer()
                        controlButtons(viewportSize: viewportSize)
                    }
                }
            }
            .padding(12)

            Spacer()

            HStack {
                legend
                Spacer()
                Text("\(snapshot.nodes.count) 个星宿 · \(snapshot.edges.count) 条灵脉")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay { Capsule().strokeBorder(AscendTheme.border(for: colorScheme), lineWidth: 0.8) }
            }
            .padding(12)
        }
    }

    private var graphTitle: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundStyle(AscendTheme.gold)
                Text("\(snapshot.name) · 星图拓扑").font(.subheadline).bold()
            }
            Text(selectedNodeID == nil
                 ? "单击选中高亮知脉 · 双击开启修道研习 · 拖拽自由排布星宿"
                 : "已聚焦知脉 · 点击空白/Esc 取消选择")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay { Capsule().strokeBorder(AscendTheme.border(for: colorScheme), lineWidth: 0.8) }
    }

    private func controlButtons(viewportSize: CGSize) -> some View {
        HStack(spacing: 4) {
            Button { zoom(by: 0.15, viewportSize: viewportSize) } label: {
                Image(systemName: "plus.magnifyingglass").font(.caption)
            }
            .buttonStyle(.bordered)
            .help("放大星图 (围绕视口中心)")

            Button { zoom(by: -0.15, viewportSize: viewportSize) } label: {
                Image(systemName: "minus.magnifyingglass").font(.caption)
            }
            .buttonStyle(.bordered)
            .help("缩小星图 (围绕视口中心)")

            Button { fitView() } label: {
                Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left").font(.caption)
            }
            .buttonStyle(.bordered)
            .help("自适应居中视野 (保持自定义排布)")

            Menu {
                Button("自适应居中视野") { fitView() }
                Button("重置星宿拖拽排布", role: .destructive) { resetLayout() }
            } label: {
                Image(systemName: "arrow.counterclockwise").font(.caption)
            }
            .menuStyle(.borderedButton)
            .help("视野复位与排布重置")
        }
        .padding(6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay { Capsule().strokeBorder(AscendTheme.border(for: colorScheme), lineWidth: 0.8) }
    }

    private var legend: some View {
        HStack(spacing: 8) {
            ConstellationLegendBadge(title: "化用", style: .gold)
            ConstellationLegendBadge(title: "通达", style: .gold)
            ConstellationLegendBadge(title: "融会", style: .jade)
            ConstellationLegendBadge(title: "通晓", style: .cobalt)
            ConstellationLegendBadge(title: "入门", style: .neutral)
            ConstellationLegendBadge(title: "初窥", style: .cinnabar)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay { Capsule().strokeBorder(AscendTheme.border(for: colorScheme), lineWidth: 0.8) }
    }

    private func zoom(by delta: CGFloat, viewportSize: CGSize) {
        let transform = viewportTransform(in: viewportSize)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            zoomScale = min(ConstellationViewportMath.maxZoomScale,
                            max(ConstellationViewportMath.minZoomScale, zoomScale + delta))
            userPanOffset = transform.userPanOffset
        }
    }

    private func fitView() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            zoomScale = 1
            userPanOffset = .zero
            panGestureStart = nil
        }
    }

    private func resetLayout() {
        onResetPersistedLayout?()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            usesCanonicalLayout = true
            positionOverrides.removeAll()
            geometryOverrides.removeAll()
            localContentBounds = snapshot.layout.canonicalContentBounds
            zoomScale = 1
            userPanOffset = .zero
            panGestureStart = nil
            onSelectNode?(nil)
        }
    }
}

private struct CelestialGraphBackground: View {
    let colorScheme: ColorScheme

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                RadialGradient(
                    colors: [Color(red: 0.05, green: 0.08, blue: 0.10), Color(red: 0.02, green: 0.03, blue: 0.04)],
                    center: .center,
                    startRadius: 20,
                    endRadius: 800
                )
            } else {
                LinearGradient(
                    colors: [Color(red: 0.985, green: 0.980, blue: 0.965), Color(red: 0.965, green: 0.955, blue: 0.935)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            Canvas { context, size in
                for index in 0..<50 {
                    let x = CGFloat((index * 157 + 73) % Int(max(1, size.width)))
                    let y = CGFloat((index * 283 + 109) % Int(max(1, size.height)))
                    let radius: CGFloat = index.isMultiple(of: 4) ? 1.5 : 0.8
                    let opacity = colorScheme == .dark
                        ? (index.isMultiple(of: 3) ? 0.35 : 0.15)
                        : (index.isMultiple(of: 3) ? 0.20 : 0.08)
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color((colorScheme == .dark ? AscendTheme.cobalt : AscendTheme.gold).opacity(opacity))
                    )
                }
            }
        }
    }
}

private struct CelestialOrbitRings: View, Equatable {
    let canvasSize: CGSize
    let colorScheme: ColorScheme

    var body: some View {
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let rx = max(160, (canvasSize.width - 180) / 2)
        let ry = max(110, (canvasSize.height - 130) / 2)
        ZStack {
            orbit(width: rx * 0.96, height: ry * 0.96, color: AscendTheme.jade.opacity(0.12), dash: [4, 8])
                .position(center)
            orbit(width: rx * 1.64, height: ry * 1.64, color: AscendTheme.gold.opacity(0.13), dash: [6, 10])
                .position(center)
            orbit(width: rx * 2, height: ry * 2, color: (colorScheme == .dark ? AscendTheme.cobalt : AscendTheme.deepJade).opacity(0.10), dash: [2, 12])
                .position(center)
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .allowsHitTesting(false)
    }

    private func orbit(width: CGFloat, height: CGFloat, color: Color, dash: [CGFloat]) -> some View {
        Ellipse().stroke(color, style: StrokeStyle(lineWidth: 1, dash: dash)).frame(width: width, height: height)
    }
}

private struct ConstellationLegendBadge: View {
    let title: String
    let style: BadgeStyle

    @MainActor
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
            Circle().fill(style.color).frame(width: 6, height: 6)
            Text(title).font(.system(size: 10, weight: .medium))
        }
    }
}
