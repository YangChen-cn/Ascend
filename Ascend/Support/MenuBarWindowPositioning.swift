import Foundation

enum MenuBarWindowPositioning {
    static func statusItemAnchorX(
        mouseLocation: CGPoint,
        screenFrame: CGRect,
        visibleFrame: CGRect
    ) -> CGFloat? {
        guard screenFrame.contains(mouseLocation),
              mouseLocation.y >= visibleFrame.maxY,
              mouseLocation.y <= screenFrame.maxY else { return nil }
        return mouseLocation.x
    }

    static func centeredOriginX(
        anchorX: CGFloat,
        windowWidth: CGFloat,
        visibleFrame: CGRect,
        margin: CGFloat = 8
    ) -> CGFloat {
        let proposed = anchorX - windowWidth / 2
        let minimum = visibleFrame.minX + margin
        let maximum = visibleFrame.maxX - windowWidth - margin
        return min(max(proposed, minimum), max(minimum, maximum))
    }
}
