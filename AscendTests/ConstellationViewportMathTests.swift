import XCTest
import SwiftUI
@testable import Ascend

final class ConstellationViewportMathTests: XCTestCase {

    // MARK: - 1. Content Bounds 计算测试

    func testContentBoundsCalculation() {
        let emptyBounds = ConstellationViewportMath.contentBounds(positions: [])
        XCTAssertEqual(emptyBounds, .zero)

        let points = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 300, y: 100),
            CGPoint(x: 200, y: 400)
        ]
        let radius: CGFloat = 40.0
        let bounds = ConstellationViewportMath.contentBounds(positions: points, nodeRadius: radius)

        XCTAssertEqual(bounds.minX, 100 - radius)
        XCTAssertEqual(bounds.minY, 100 - radius)
        XCTAssertEqual(bounds.maxX, 300 + radius)
        XCTAssertEqual(bounds.maxY, 400 + radius)
        XCTAssertEqual(bounds.width, 200 + radius * 2)
        XCTAssertEqual(bounds.height, 300 + radius * 2)
    }

    // MARK: - 2. Fit to Content 测试

    func testFitToContentFitsNodesInSafeViewport() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1000, y: 600)
        ]
        let bounds = ConstellationViewportMath.contentBounds(positions: points, nodeRadius: 50)
        let viewportSize = CGSize(width: 800, height: 500)
        let safeInsets = EdgeInsets(top: 60, leading: 60, bottom: 60, trailing: 60)

        let (scale, offset) = ConstellationViewportMath.fitTransform(
            contentBounds: bounds,
            viewportSize: viewportSize,
            safeInsets: safeInsets
        )

        // 验证 scale 被合理计算且在限制范围内
        XCTAssertGreaterThanOrEqual(scale, ConstellationViewportMath.minZoomScale)
        XCTAssertLessThanOrEqual(scale, 1.25)

        // 验证在计算出的 scale 与 offset 变换后，bounds 中心落在 safeCenter
        let viewportCenter = CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
        let safeCenter = CGPoint(
            x: safeInsets.leading + (viewportSize.width - safeInsets.leading - safeInsets.trailing) / 2,
            y: safeInsets.top + (viewportSize.height - safeInsets.top - safeInsets.bottom) / 2
        )

        let scaledMidX = viewportCenter.x + (bounds.midX - viewportCenter.x) * scale
        let scaledMidY = viewportCenter.y + (bounds.midY - viewportCenter.y) * scale

        let actualCenterX = scaledMidX + offset.width
        let actualCenterY = scaledMidY + offset.height

        XCTAssertEqual(actualCenterX, safeCenter.x, accuracy: 0.001)
        XCTAssertEqual(actualCenterY, safeCenter.y, accuracy: 0.001)
    }

    // MARK: - 3. Zoom 围绕中心与中心点保持测试

    func testZoomTransformMaintainsCenterSymmetry() {
        let initialOffset = CGSize(width: 50, height: -30)
        let oldScale: CGFloat = 1.0
        let newScale: CGFloat = 1.2

        let scaledOffset = ConstellationViewportMath.zoomTransform(
            oldScale: oldScale,
            newScale: newScale,
            currentOffset: initialOffset
        )

        XCTAssertEqual(scaledOffset.width, 60.0, accuracy: 0.001)
        XCTAssertEqual(scaledOffset.height, -36.0, accuracy: 0.001)
    }

    // MARK: - 4. Extreme Pan Clamping 测试

    func testExtremePanIsClamped() {
        let bounds = CGRect(x: 200, y: 150, width: 400, height: 300)
        let viewportSize = CGSize(width: 1000, height: 600)

        // 极端往左拖拽 -5000
        let extremeLeft = CGSize(width: -5000, height: 0)
        let clampedLeft = ConstellationViewportMath.clampedPanOffset(
            proposedOffset: extremeLeft,
            zoomScale: 1.0,
            contentBounds: bounds,
            viewportSize: viewportSize
        )
        XCTAssertGreaterThan(clampedLeft.width, -2000, "极端向左平移必须被 clamp，不能把图拖没")

        // 极端往右拖拽 +5000
        let extremeRight = CGSize(width: 5000, height: 0)
        let clampedRight = ConstellationViewportMath.clampedPanOffset(
            proposedOffset: extremeRight,
            zoomScale: 1.0,
            contentBounds: bounds,
            viewportSize: viewportSize
        )
        XCTAssertLessThan(clampedRight.width, 2000, "极端向右平移必须被 clamp")
    }

    // MARK: - 5. Viewport 缩小（Inspector 打开从 1200 缩小到 700）测试

    func testViewportResizeClampsOffsetWithoutDriftingOut() {
        let bounds = CGRect(x: 300, y: 200, width: 600, height: 400)
        let wideViewport = CGSize(width: 1200, height: 600)
        let narrowViewport = CGSize(width: 700, height: 600)

        // 在宽视口下的偏置
        let initialOffset = CGSize(width: 300, height: 50)
        let clampedInWide = ConstellationViewportMath.clampedPanOffset(
            proposedOffset: initialOffset,
            zoomScale: 1.0,
            contentBounds: bounds,
            viewportSize: wideViewport
        )

        // 突然视口变窄为 700（Inspector 打开）
        let clampedInNarrow = ConstellationViewportMath.clampedPanOffset(
            proposedOffset: clampedInWide,
            zoomScale: 1.0,
            contentBounds: bounds,
            viewportSize: narrowViewport
        )

        // 确认窄视口下依然有合法的约束范围，不会越界漂移
        XCTAssertNotNil(clampedInNarrow)
        XCTAssertLessThanOrEqual(abs(clampedInNarrow.width), 1000)
    }
}
