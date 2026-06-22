import CoreGraphics

enum PaperBananaWindowPlacement {
    static let minimumScreenMargin: CGFloat = 20
    private static let preferredTopMargin: CGFloat = 32
    private static let preferredMinimumWidth: CGFloat = 1280
    private static let preferredMinimumHeight: CGFloat = 860
    static let minimumUsableWindowWidth: CGFloat = 1120
    static let minimumUsableWindowHeight: CGFloat = 760

    static func frame(currentFrame: CGRect, codexBounds: CGRect, visibleFrame: CGRect) -> CGRect {
        let availableWidth = max(visibleFrame.width - (minimumScreenMargin * 2), minimumUsableWindowWidth)
        let availableHeight = max(visibleFrame.height - (minimumScreenMargin * 2), minimumUsableWindowHeight)
        let width = min(max(currentFrame.width, preferredMinimumWidth), availableWidth)
        let height = min(max(currentFrame.height, preferredMinimumHeight), availableHeight)

        let preferredX = codexBounds.minX + minimumScreenMargin
        let x = clamp(
            preferredX,
            lower: visibleFrame.minX + minimumScreenMargin,
            upper: visibleFrame.maxX - width - minimumScreenMargin
        )
        let preferredY = visibleFrame.maxY - height - preferredTopMargin
        let y = clamp(
            preferredY,
            lower: visibleFrame.minY + minimumScreenMargin,
            upper: visibleFrame.maxY - height - minimumScreenMargin
        )

        return CGRect(x: x, y: y, width: width, height: height)
    }

    static func clampedFrame(currentFrame: CGRect, minimumSize: CGSize, visibleFrame: CGRect) -> CGRect {
        let targetWidth = min(
            max(currentFrame.width, minimumSize.width, minimumUsableWindowWidth),
            max(visibleFrame.width - minimumScreenMargin * 2, minimumUsableWindowWidth)
        )
        let targetHeight = min(
            max(currentFrame.height, minimumSize.height, minimumUsableWindowHeight),
            max(visibleFrame.height - minimumScreenMargin * 2, minimumUsableWindowHeight)
        )
        let x = clamp(
            currentFrame.minX,
            lower: visibleFrame.minX + minimumScreenMargin,
            upper: visibleFrame.maxX - targetWidth - minimumScreenMargin
        )
        let y = clamp(
            currentFrame.minY,
            lower: visibleFrame.minY + minimumScreenMargin,
            upper: visibleFrame.maxY - targetHeight - minimumScreenMargin
        )
        return CGRect(x: x, y: y, width: targetWidth, height: targetHeight)
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        guard lower <= upper else { return lower }
        return min(max(value, lower), upper)
    }
}
