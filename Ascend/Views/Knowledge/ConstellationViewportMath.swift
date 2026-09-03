import Foundation
import SwiftUI

struct ConstellationViewportMath: Sendable {
    static let minZoomScale: CGFloat = 0.65
    static let maxZoomScale: CGFloat = 1.80
    static let defaultNodeRadius: CGFloat = 42.0

    struct ViewportTransform: Sendable, Equatable {
        let xScale: CGFloat
        let yScale: CGFloat
        let nodeScale: CGFloat
        let offset: CGSize
        let userPanOffset: CGSize

        var scale: CGFloat { min(xScale, yScale) }
    }

    /// 计算所有节点的外包矩形（包含节点安全半径）
    static func contentBounds(
        positions: [CGPoint],
        nodeRadius: CGFloat = defaultNodeRadius
    ) -> CGRect {
        guard !positions.isEmpty else { return .zero }
        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity

        for pt in positions {
            minX = min(minX, pt.x)
            minY = min(minY, pt.y)
            maxX = max(maxX, pt.x)
            maxY = max(maxY, pt.y)
        }

        return CGRect(
            x: minX - nodeRadius,
            y: minY - nodeRadius,
            width: max(1.0, (maxX - minX) + nodeRadius * 2),
            height: max(1.0, (maxY - minY) + nodeRadius * 2)
        )
    }

    /// 节点标题是单行文本，横向占用明显大于星点本身。自适应视野必须把标题也纳入安全边界。
    static func renderContentBounds(positions: [CGPoint]) -> CGRect {
        contentBounds(positions: positions)
            .insetBy(dx: -36, dy: -12)
    }

    /// 计算适合当前视口的缩放比和居中平移量
    static func fitTransform(
        contentBounds: CGRect,
        viewportSize: CGSize,
        safeInsets: EdgeInsets = EdgeInsets(top: 60, leading: 60, bottom: 64, trailing: 60),
        minScale: CGFloat = minZoomScale,
        maxScale: CGFloat = 1.25
    ) -> (scale: CGFloat, offset: CGSize) {
        guard viewportSize.width > 0, viewportSize.height > 0, contentBounds.width > 0, contentBounds.height > 0 else {
            return (1.0, .zero)
        }

        let safeWidth = max(50.0, viewportSize.width - safeInsets.leading - safeInsets.trailing)
        let safeHeight = max(50.0, viewportSize.height - safeInsets.top - safeInsets.bottom)

        let rawScale = min(safeWidth / contentBounds.width, safeHeight / contentBounds.height)
        let scale = min(maxScale, max(minScale, rawScale))

        let viewportCenter = CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
        let safeCenter = CGPoint(
            x: safeInsets.leading + safeWidth / 2,
            y: safeInsets.top + safeHeight / 2
        )

        // 在 scaleEffect(scale) (以 viewportCenter 为中心缩放) 作用下：
        // contentBounds 中心点 midX/midY 在缩放后相对于 viewportCenter 的位置为：
        // scaledMidX = viewportCenter.x + (contentBounds.midX - viewportCenter.x) * scale
        // scaledMidY = viewportCenter.y + (contentBounds.midY - viewportCenter.y) * scale
        // 我们希望 scaledMid + offset = safeCenter
        // 因此 offset = safeCenter - scaledMid
        let scaledMidX = viewportCenter.x + (contentBounds.midX - viewportCenter.x) * scale
        let scaledMidY = viewportCenter.y + (contentBounds.midY - viewportCenter.y) * scale

        let offsetX = safeCenter.x - scaledMidX
        let offsetY = safeCenter.y - scaledMidY

        return (scale, CGSize(width: offsetX, height: offsetY))
    }

    /// 限制平移偏移，防止星图内容被完全拖出视口
    static func clampedPanOffset(
        proposedOffset: CGSize,
        zoomScale: CGFloat,
        contentBounds: CGRect,
        viewportSize: CGSize,
        safeInsets: EdgeInsets = EdgeInsets(top: 58, leading: 50, bottom: 62, trailing: 50)
    ) -> CGSize {
        guard viewportSize.width > 0, viewportSize.height > 0 else { return proposedOffset }

        let viewportCenter = CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
        let safeCenter = CGPoint(
            x: safeInsets.leading + (viewportSize.width - safeInsets.leading - safeInsets.trailing) / 2,
            y: safeInsets.top + (viewportSize.height - safeInsets.top - safeInsets.bottom) / 2
        )

        let targetBounds = contentBounds.isEmpty
            ? CGRect(x: viewportSize.width * 0.1, y: viewportSize.height * 0.1, width: viewportSize.width * 0.8, height: viewportSize.height * 0.8)
            : contentBounds

        let contentMidX = targetBounds.midX
        let contentMidY = targetBounds.midY

        let scaledMidX = viewportCenter.x + (contentMidX - viewportCenter.x) * zoomScale
        let scaledMidY = viewportCenter.y + (contentMidY - viewportCenter.y) * zoomScale

        let idealOffsetX = safeCenter.x - scaledMidX
        let idealOffsetY = safeCenter.y - scaledMidY

        // 允许在理想居中位置周围平移的合理阈值
        let maxPanDeltaX = max(100.0, (targetBounds.width * zoomScale) * 0.45 + (viewportSize.width * 0.35))
        let maxPanDeltaY = max(80.0, (targetBounds.height * zoomScale) * 0.45 + (viewportSize.height * 0.30))

        let clampedX = min(max(proposedOffset.width, idealOffsetX - maxPanDeltaX), idealOffsetX + maxPanDeltaX)
        let clampedY = min(max(proposedOffset.height, idealOffsetY - maxPanDeltaY), idealOffsetY + maxPanDeltaY)

        return CGSize(width: clampedX, height: clampedY)
    }

    /// 围绕视口中心进行平滑对称缩放
    static func zoomTransform(
        oldScale: CGFloat,
        newScale: CGFloat,
        currentOffset: CGSize
    ) -> CGSize {
        guard oldScale > 0.001 else { return currentOffset }
        let scaleRatio = newScale / oldScale
        return CGSize(
            width: currentOffset.width * scaleRatio,
            height: currentOffset.height * scaleRatio
        )
    }

    /// 将稳定逻辑画布映射到实时 viewport。窗口和 Inspector 动画只会执行这段 O(1) 变换。
    static func viewportTransform(
        logicalCanvasSize: CGSize,
        contentBounds: CGRect,
        viewportSize: CGSize,
        userZoomScale: CGFloat,
        proposedUserPanOffset: CGSize,
        safeInsets: EdgeInsets = EdgeInsets(top: 66, leading: 32, bottom: 60, trailing: 32)
    ) -> ViewportTransform {
        guard logicalCanvasSize.width > 0,
              logicalCanvasSize.height > 0,
              viewportSize.width > 0,
              viewportSize.height > 0 else {
            return ViewportTransform(
                xScale: userZoomScale,
                yScale: userZoomScale,
                nodeScale: userZoomScale,
                offset: proposedUserPanOffset,
                userPanOffset: proposedUserPanOffset
            )
        }

        let targetBounds = contentBounds.isEmpty
            ? CGRect(origin: .zero, size: logicalCanvasSize)
            : contentBounds
        let safeWidth = max(50, viewportSize.width - safeInsets.leading - safeInsets.trailing)
        let safeHeight = max(50, viewportSize.height - safeInsets.top - safeInsets.bottom)
        var fitX = min(1, safeWidth / targetBounds.width)
        var fitY = min(1, safeHeight / targetBounds.height)
        // Inspector 会形成偏纵向的 viewport。限制坐标场的非等比程度，在利用纵向空白的同时避免拓扑形变过强。
        let maximumAxisRatio: CGFloat = 1.60
        fitX = min(fitX, fitY * maximumAxisRatio)
        fitY = min(fitY, fitX * maximumAxisRatio)
        let zoom = min(maxZoomScale, max(minZoomScale, userZoomScale))
        let xScale = fitX * zoom
        let yScale = fitY * zoom
        // 星点和标题不随狭窄坐标场无限缩小，确保视觉与命中区域仍可用。
        let nodeScale = min(maxZoomScale, max(0.78, min(fitX, fitY)) * zoom)
        let viewportCenter = CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
        let logicalCenter = CGPoint(x: logicalCanvasSize.width / 2, y: logicalCanvasSize.height / 2)
        let safeCenter = CGPoint(
            x: safeInsets.leading + safeWidth / 2,
            y: safeInsets.top + safeHeight / 2
        )
        let contentCenterDelta = CGPoint(
            x: (targetBounds.midX - logicalCenter.x) * xScale,
            y: (targetBounds.midY - logicalCenter.y) * yScale
        )
        let idealOffset = CGSize(
            width: safeCenter.x - viewportCenter.x - contentCenterDelta.x,
            height: safeCenter.y - viewportCenter.y - contentCenterDelta.y
        )
        let clampedPan = clampedUserPanOffset(
            proposedOffset: proposedUserPanOffset,
            xScale: xScale,
            yScale: yScale,
            contentBounds: targetBounds,
            viewportSize: viewportSize
        )
        return ViewportTransform(
            xScale: xScale,
            yScale: yScale,
            nodeScale: nodeScale,
            offset: CGSize(
                width: idealOffset.width + clampedPan.width,
                height: idealOffset.height + clampedPan.height
            ),
            userPanOffset: clampedPan
        )
    }

    static func clampedUserPanOffset(
        proposedOffset: CGSize,
        xScale: CGFloat,
        yScale: CGFloat,
        contentBounds: CGRect,
        viewportSize: CGSize
    ) -> CGSize {
        let maxPanX = max(100, contentBounds.width * xScale * 0.45 + viewportSize.width * 0.35)
        let maxPanY = max(80, contentBounds.height * yScale * 0.45 + viewportSize.height * 0.30)
        return CGSize(
            width: min(max(proposedOffset.width, -maxPanX), maxPanX),
            height: min(max(proposedOffset.height, -maxPanY), maxPanY)
        )
    }
}
