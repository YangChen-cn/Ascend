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

    // MARK: - 2. Fit to Content 变换后全部位于 Safe Viewport 内

    func testFitToContentPutsAllBoundsWithinSafeViewport() {
        let points = [
            CGPoint(x: 50, y: 50),
            CGPoint(x: 950, y: 550)
        ]
        let bounds = ConstellationViewportMath.contentBounds(positions: points, nodeRadius: 40)
        let viewportSize = CGSize(width: 800, height: 500)
        let safeInsets = EdgeInsets(top: 60, leading: 60, bottom: 64, trailing: 60)

        let (scale, offset) = ConstellationViewportMath.fitTransform(
            contentBounds: bounds,
            viewportSize: viewportSize,
            safeInsets: safeInsets
        )

        let viewportCenter = CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
        let transMinX = viewportCenter.x + (bounds.minX - viewportCenter.x) * scale + offset.width
        let transMaxX = viewportCenter.x + (bounds.maxX - viewportCenter.x) * scale + offset.width
        let transMinY = viewportCenter.y + (bounds.minY - viewportCenter.y) * scale + offset.height
        let transMaxY = viewportCenter.y + (bounds.maxY - viewportCenter.y) * scale + offset.height

        let safeMinX = safeInsets.leading
        let safeMaxX = viewportSize.width - safeInsets.trailing
        let safeMinY = safeInsets.top
        let safeMaxY = viewportSize.height - safeInsets.bottom

        // 断言全部 bounds 落在安全可视区之内（允许 0.5px 的数值浮点误差）
        XCTAssertGreaterThanOrEqual(transMinX, safeMinX - 0.5, "变换后左边界必须落在 Safe Viewport 内")
        XCTAssertLessThanOrEqual(transMaxX, safeMaxX + 0.5, "变换后右边界必须落在 Safe Viewport 内")
        XCTAssertGreaterThanOrEqual(transMinY, safeMinY - 0.5, "变换后上边界必须落在 Safe Viewport 内")
        XCTAssertLessThanOrEqual(transMaxY, safeMaxY + 0.5, "变换后下边界必须落在 Safe Viewport 内")
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

    // MARK: - 4. 极端平移 Clamping 确保内容不会完全离开视口

    func testExtremePanContentRemainsInSafeViewport() {
        let bounds = CGRect(x: 200, y: 150, width: 400, height: 300)
        let viewportSize = CGSize(width: 1000, height: 600)
        let viewportRect = CGRect(origin: .zero, size: viewportSize)
        let viewportCenter = CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)

        // 模拟极端往左拖拽 -10000
        let clampedLeft = ConstellationViewportMath.clampedPanOffset(
            proposedOffset: CGSize(width: -10000, height: 0),
            zoomScale: 1.0,
            contentBounds: bounds,
            viewportSize: viewportSize
        )

        let transLeftRect = CGRect(
            x: viewportCenter.x + (bounds.minX - viewportCenter.x) * 1.0 + clampedLeft.width,
            y: viewportCenter.y + (bounds.minY - viewportCenter.y) * 1.0 + clampedLeft.height,
            width: bounds.width,
            height: bounds.height
        )

        let leftIntersection = transLeftRect.intersection(viewportRect)
        XCTAssertFalse(leftIntersection.isNull, "极端左拉后星图绝不能完全离开视口")
        XCTAssertGreaterThan(leftIntersection.width * leftIntersection.height, 5000, "必须保留显著的可见区域")

        // 模拟极端往右拖拽 +10000
        let clampedRight = ConstellationViewportMath.clampedPanOffset(
            proposedOffset: CGSize(width: 10000, height: 0),
            zoomScale: 1.0,
            contentBounds: bounds,
            viewportSize: viewportSize
        )

        let transRightRect = CGRect(
            x: viewportCenter.x + (bounds.minX - viewportCenter.x) * 1.0 + clampedRight.width,
            y: viewportCenter.y + (bounds.minY - viewportCenter.y) * 1.0 + clampedRight.height,
            width: bounds.width,
            height: bounds.height
        )

        let rightIntersection = transRightRect.intersection(viewportRect)
        XCTAssertFalse(rightIntersection.isNull, "极端右拉后星图绝不能完全离开视口")
        XCTAssertGreaterThan(rightIntersection.width * rightIntersection.height, 5000)
    }

    // MARK: - 5. Viewport 缩小（Inspector 打开从 1200 缩小到 700）保持有效可见区

    func testViewportResizeFrom1200To700MaintainsVisibleArea() {
        let bounds = CGRect(x: 300, y: 200, width: 600, height: 400)
        let wideViewport = CGSize(width: 1200, height: 600)
        let narrowViewport = CGSize(width: 700, height: 600)

        // 在宽视口下的平移偏移
        let initialOffset = CGSize(width: 250, height: 30)
        let clampedInWide = ConstellationViewportMath.clampedPanOffset(
            proposedOffset: initialOffset,
            zoomScale: 1.0,
            contentBounds: bounds,
            viewportSize: wideViewport
        )

        // Inspector 展开后视口变窄为 700
        let clampedInNarrow = ConstellationViewportMath.clampedPanOffset(
            proposedOffset: clampedInWide,
            zoomScale: 1.0,
            contentBounds: bounds,
            viewportSize: narrowViewport
        )

        let narrowCenter = CGPoint(x: narrowViewport.width / 2, y: narrowViewport.height / 2)
        let transformedNarrowRect = CGRect(
            x: narrowCenter.x + (bounds.minX - narrowCenter.x) * 1.0 + clampedInNarrow.width,
            y: narrowCenter.y + (bounds.minY - narrowCenter.y) * 1.0 + clampedInNarrow.height,
            width: bounds.width,
            height: bounds.height
        )

        let narrowViewportRect = CGRect(origin: .zero, size: narrowViewport)
        let visibleIntersection = transformedNarrowRect.intersection(narrowViewportRect)

        XCTAssertFalse(visibleIntersection.isNull, "Inspector 打开后星图内容必须保持在窄视口内可见")
        XCTAssertGreaterThan(visibleIntersection.width * visibleIntersection.height, 10_000, "窄视口下必须保留显著有效可见面积")
    }

    func testStableLogicalCanvasFitIncludesNodeLabelsAtWideAndInspectorWidths() {
        let logicalSize = CGSize(width: 1_100, height: 650)
        let positions = [CGPoint(x: 78, y: 62), CGPoint(x: 1_022, y: 588)]
        let bounds = ConstellationViewportMath.renderContentBounds(positions: positions)
        let safeInsets = EdgeInsets(top: 60, leading: 60, bottom: 64, trailing: 60)

        for viewportSize in [CGSize(width: 1_200, height: 640), CGSize(width: 700, height: 640), CGSize(width: 480, height: 640)] {
            let transform = ConstellationViewportMath.viewportTransform(
                logicalCanvasSize: logicalSize,
                contentBounds: bounds,
                viewportSize: viewportSize,
                userZoomScale: 1,
                proposedUserPanOffset: .zero,
                safeInsets: safeInsets
            )
            let viewportCenter = CGPoint(x: viewportSize.width / 2, y: viewportSize.height / 2)
            let logicalCenter = CGPoint(x: logicalSize.width / 2, y: logicalSize.height / 2)
            let projected = CGRect(
                x: viewportCenter.x + transform.offset.width + (bounds.minX - logicalCenter.x) * transform.xScale,
                y: viewportCenter.y + transform.offset.height + (bounds.minY - logicalCenter.y) * transform.yScale,
                width: bounds.width * transform.xScale,
                height: bounds.height * transform.yScale
            )

            XCTAssertGreaterThanOrEqual(projected.minX, safeInsets.leading - 0.5)
            XCTAssertLessThanOrEqual(projected.maxX, viewportSize.width - safeInsets.trailing + 0.5)
            XCTAssertGreaterThanOrEqual(projected.minY, safeInsets.top - 0.5)
            XCTAssertLessThanOrEqual(projected.maxY, viewportSize.height - safeInsets.bottom + 0.5)
            XCTAssertGreaterThanOrEqual(transform.nodeScale, 0.78)
            XCTAssertLessThanOrEqual(
                max(transform.xScale, transform.yScale) / min(transform.xScale, transform.yScale),
                1.60 + 0.001
            )
        }
    }
}
