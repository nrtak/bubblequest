import XCTest
@testable import BubbleQuest

final class MapScrollMomentumTests: XCTestCase {
    private func flick(_ distance: CGFloat = -100) -> MapScrollMomentum {
        var motion = MapScrollMomentum()
        motion.begin(at: 400, time: 0)
        motion.drag(to: 400 + distance, time: 0.05)
        motion.end(time: 0.06)
        return motion
    }
    func testFlickGlidesInSwipeDirectionAndSettles() {
        var motion = flick()
        var offset: CGFloat = -1000
        let initial = offset
        for _ in 0..<180 {
            let next = motion.advance(offset: offset, by: 1.0 / 60)
            XCTAssertLessThanOrEqual(next, offset)
            offset = next
        }
        XCTAssertFalse(motion.isMoving)
        XCTAssertLessThan(offset, initial - 100)
        XCTAssertGreaterThan(offset, initial - 300)
    }
    func testGlideDistanceDoesNotDependOnScreenFrameRate() {
        func distance(rate: Int) -> CGFloat {
            var motion = flick(); var offset: CGFloat = -1000
            for _ in 0..<(rate * 3) { offset = motion.advance(offset: offset, by: 1.0 / Double(rate)) }
            return offset
        }
        XCTAssertEqual(distance(rate: 30), distance(rate: 120), accuracy: 2)
    }
    func testEdgesStopMomentumWithoutOvershooting() {
        var upward = flick(100)
        XCTAssertEqual(upward.advance(offset: 135, by: 1.0 / 60), 136)
        XCTAssertFalse(upward.isMoving)
        var downward = flick()
        let end = FestivalMapLayout.scrollOffset(-100000)
        XCTAssertEqual(downward.advance(offset: end + 1, by: 1.0 / 60), end)
        XCTAssertFalse(downward.isMoving)
    }
    func testPauseBeforeReleaseAndNewTouchCancelTheGlide() {
        var motion = flick()
        XCTAssertTrue(motion.isMoving)
        motion.begin(at: 300, time: 1)
        XCTAssertFalse(motion.isMoving)
        motion.drag(to: 200, time: 1.05)
        motion.end(time: 1.3)
        XCTAssertFalse(motion.isMoving)
    }
    func testBackgroundGapsAndInvalidSamplesCannotJumpTheMap() {
        var motion = flick()
        XCTAssertEqual(motion.advance(offset: -1000, by: 3), -1000)
        XCTAssertFalse(motion.isMoving)
        motion.begin(at: .nan, time: 0)
        motion.drag(to: 300, time: 0.05)
        motion.end(time: 0.06)
        XCTAssertFalse(motion.isMoving)
    }
    func testSceneryJoinIsOpaqueOrClearExceptForANarrowEdge() {
        for x in stride(from: CGFloat(0), through: 390, by: 5) {
            XCTAssertEqual(FestivalMapLayout.sceneryBlend(fromBottom: 0, x: x), 0)
            XCTAssertEqual(FestivalMapLayout.sceneryBlend(fromBottom: 128, x: x), 1)
            let translucent = (0..<128).filter {
                let alpha = FestivalMapLayout.sceneryBlend(fromBottom: CGFloat($0), x: x)
                return alpha > 0 && alpha < 1
            }
            XCTAssertLessThanOrEqual(translucent.count, 40)
        }
    }
}
