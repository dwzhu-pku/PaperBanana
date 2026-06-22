import CoreGraphics
import XCTest
@testable import PaperBanana

final class WindowPlacementTests: XCTestCase {
    func testRuntimeEnvironmentDetectsXcodeUnitTests() {
        XCTAssertTrue(PaperBananaRuntimeEnvironment.isRunningUnitTests)
    }

    func testPlacementKeepsWindowInsideVisibleScreenWhenCodexIsFlushLeft() {
        let visibleFrame = CGRect(x: 3273, y: 80, width: 1920, height: 1080)
        let codexBounds = CGRect(x: 3273, y: 740, width: 1203, height: 822)
        let currentFrame = CGRect(x: 3273, y: 640, width: 1420, height: 980)

        let placement = PaperBananaWindowPlacement.frame(
            currentFrame: currentFrame,
            codexBounds: codexBounds,
            visibleFrame: visibleFrame
        )

        XCTAssertGreaterThanOrEqual(placement.minX, visibleFrame.minX + PaperBananaWindowPlacement.minimumScreenMargin)
        XCTAssertLessThanOrEqual(placement.maxX, visibleFrame.maxX - PaperBananaWindowPlacement.minimumScreenMargin)
        XCTAssertGreaterThanOrEqual(placement.minY, visibleFrame.minY + PaperBananaWindowPlacement.minimumScreenMargin)
        XCTAssertLessThanOrEqual(placement.maxY, visibleFrame.maxY - PaperBananaWindowPlacement.minimumScreenMargin)
    }

    func testClampCorrectsRestoredWindowThatWouldHideSidebarOffscreen() {
        let visibleFrame = CGRect(x: 0, y: 25, width: 1440, height: 875)
        let restoredFrame = CGRect(x: -228, y: 80, width: 1600, height: 900)

        let clamped = PaperBananaWindowPlacement.clampedFrame(
            currentFrame: restoredFrame,
            minimumSize: CGSize(
                width: PaperBananaWindowPlacement.minimumUsableWindowWidth,
                height: PaperBananaWindowPlacement.minimumUsableWindowHeight
            ),
            visibleFrame: visibleFrame
        )

        XCTAssertEqual(clamped.minX, visibleFrame.minX + PaperBananaWindowPlacement.minimumScreenMargin)
        XCTAssertGreaterThanOrEqual(clamped.width, PaperBananaWindowPlacement.minimumUsableWindowWidth)
        XCTAssertLessThanOrEqual(clamped.maxX, visibleFrame.maxX - PaperBananaWindowPlacement.minimumScreenMargin)
    }
}
