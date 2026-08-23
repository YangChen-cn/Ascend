import Foundation
import SwiftUI

struct ConstellationViewportMath: Sendable {
    static let minZoomScale: CGFloat = 0.65
    static let maxZoomScale: CGFloat = 1.80
    static let defaultNodeRadius: CGFloat = 42.0

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
}
