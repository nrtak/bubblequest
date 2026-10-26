import XCTest
@testable import BubbleQuest

final class AimGestureTests: XCTestCase {
    func testDownwardLiftCancelsWithoutFinalMoveEvent() {
        var gesture = AimGesture()
        gesture.begin(at: BubblePoint(x: 250, y: 600))
        XCTAssertNil(gesture.end(at: BubblePoint(x: 195, y: 175)))
        XCTAssertFalse(gesture.isActive)
    }

    func testLiftJitterDoesNotChangePreviewedLanding() {
        var gesture = AimGesture()
        gesture.begin(at: BubblePoint(x: 270, y: 550))
        gesture.update(at: BubblePoint(x: 245, y: 570))
        let angle = gesture.angle
        let board = LevelCatalog.level(7).board
        let preview = BubbleGeometry.flight(angle: angle, board: board)
        let released = gesture.end(at: BubblePoint(x: 180, y: 560))
        XCTAssertEqual(released, angle)
        XCTAssertEqual(BubbleGeometry.flight(angle: released!, board: board).landing, preview.landing)
        XCTAssertFalse(gesture.isActive)
    }

    func testDraggingDownCancelsAndReturningUpRestoresAim() {
        var gesture = AimGesture()
        gesture.begin(at: BubblePoint(x: 245, y: 570))
        let previewAngle = gesture.angle
        gesture.update(at: BubblePoint(x: 120, y: 200))
        XCTAssertTrue(gesture.shouldCancel)
        XCTAssertEqual(gesture.angle, previewAngle)
        XCTAssertNil(gesture.end(at: BubblePoint(x: 120, y: 200)))
        gesture.begin(at: BubblePoint(x: 245, y: 570))
        gesture.update(at: BubblePoint(x: 120, y: 200))
        gesture.update(at: BubblePoint(x: 225, y: 600))
        XCTAssertFalse(gesture.shouldCancel)
        XCTAssertNotNil(gesture.end(at: BubblePoint(x: 225, y: 600)))
    }

    func testSystemCancellationAndRepeatedReleaseCannotFire() {
        var gesture = AimGesture()
        gesture.begin(at: BubblePoint(x: 250, y: 600))
        gesture.cancel()
        XCTAssertNil(gesture.end(at: nil))
        gesture.begin(at: BubblePoint(x: 250, y: 600))
        XCTAssertNotNil(gesture.end(at: nil))
        XCTAssertNil(gesture.end(at: nil))
    }
}
