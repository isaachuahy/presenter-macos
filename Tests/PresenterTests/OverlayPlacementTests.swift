import Foundation
import Testing
@testable import Presenter

struct OverlayPlacementTests {
    private let desktop = CGRect(x: 0, y: 24, width: 1440, height: 876)

    @Test func newOverlayHasBottomRightMargin() {
        let frame = OverlayPlacement.frame(preferred: nil, size: CGSize(width: 224, height: 224), screens: [desktop])
        #expect(frame == CGRect(x: 1192, y: 48, width: 224, height: 224))
    }

    @Test func resizingKeepsTheCameraCenter() {
        let saved = CGRect(x: 300, y: 200, width: 160, height: 160)
        let frame = OverlayPlacement.frame(preferred: saved, size: CGSize(width: 320, height: 240), screens: [desktop])
        #expect(frame.midX == saved.midX)
        #expect(frame.midY == saved.midY)
        #expect(frame.size == CGSize(width: 320, height: 240))
    }

    @Test func negativeCoordinatesStayOnSecondaryDisplay() {
        let secondary = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
        let saved = CGRect(x: -1800, y: -100, width: 224, height: 224)
        let frame = OverlayPlacement.frame(preferred: saved, size: saved.size, screens: [desktop, secondary])
        #expect(frame == saved)
    }

    @Test func disconnectedDisplayFallsBackInsideMainDisplay() {
        let saved = CGRect(x: -1800, y: 200, width: 224, height: 224)
        let frame = OverlayPlacement.frame(preferred: saved, size: saved.size, screens: [desktop])
        #expect(desktop.contains(frame))
        #expect(frame.minX == desktop.minX)
    }

    @Test func overlayCannotBeStrandedOutsideVisibleBounds() {
        let saved = CGRect(x: 1390, y: 850, width: 224, height: 224)
        let frame = OverlayPlacement.frame(preferred: saved, size: saved.size, screens: [desktop])
        #expect(desktop.contains(frame))
        #expect(frame.maxX == desktop.maxX)
        #expect(frame.maxY == desktop.maxY)
    }

    @Test func oversizedOverlayFitsSmallDisplay() {
        let tiny = CGRect(x: -100, y: 30, width: 120, height: 90)
        let frame = OverlayPlacement.frame(preferred: nil, size: CGSize(width: 320, height: 320), screens: [tiny])
        #expect(frame == tiny)
    }

    @Test func corruptSavedCoordinatesAndDimensionsRemainFinite() {
        let corrupt = CGRect(x: CGFloat.nan, y: 0, width: 200, height: 200)
        let frame = OverlayPlacement.frame(
            preferred: corrupt,
            size: CGSize(width: CGFloat.infinity, height: -1),
            screens: [.zero, desktop]
        )
        #expect(desktop.contains(frame))
        #expect(frame.size == CGSize(width: 224, height: 224))
    }

    @Test func noDisplayDuringTransitionReturnsSafeFrame() {
        let frame = OverlayPlacement.frame(preferred: nil, size: CGSize(width: 224, height: 168), screens: [])
        #expect(frame == CGRect(x: 0, y: 0, width: 224, height: 168))
    }
}
