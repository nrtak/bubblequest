import XCTest
@testable import BubbleQuest

final class OperatorArmTests: XCTestCase {
    func testGripStaysOnRotatingKnobWithoutStretchingEitherArmSegment() {
        for step in -120...120 {
            let angle = Double(step) / 100
            let pose = OperatorArmPose.aiming(angle)
            XCTAssertEqual(hypot(pose.hand.x - 280, pose.hand.y - 173), 18, accuracy: 0.000001)
            XCTAssertEqual(hypot(pose.elbow.x - pose.shoulder.x, pose.elbow.y - pose.shoulder.y), OperatorArmPose.upperLength, accuracy: 0.000001)
            XCTAssertEqual(hypot(pose.hand.x - pose.elbow.x, pose.hand.y - pose.elbow.y), OperatorArmPose.forearmLength, accuracy: 0.000001)
            let rotation = -angle * 2.5
            XCTAssertEqual(pose.hand.x, 280 - sin(rotation) * 18, accuracy: 0.000001)
            XCTAssertEqual(pose.hand.y, 173 + cos(rotation) * 18, accuracy: 0.000001)
        }
    }
}
