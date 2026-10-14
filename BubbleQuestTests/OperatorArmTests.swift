import XCTest
import SpriteKit
@testable import BubbleQuest

final class OperatorArmTests: XCTestCase {
    @MainActor
    func testRenderedFistRemainsOnActualCrankAcrossWheelRotations() throws {
        let scene = FestivalScene(size: CGSize(width: 390, height: 844))
        scene.didMove(to: SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)))
        let wheel = try XCTUnwrap(scene.childNode(withName: "//handwheel"))
        let knob = try XCTUnwrap(wheel.childNode(withName: "crank"))
        let grip = try XCTUnwrap(knob.childNode(withName: "operator-grip"))
        XCTAssertTrue(grip.parent === knob)
        wheel.parent?.isPaused = false
        for step in -30...30 {
            wheel.zRotation = CGFloat(step) / 10
            scene.didFinishUpdate()
            let contact = grip.convert(CGPoint.zero, to: scene)
            let crank = knob.convert(CGPoint.zero, to: scene)
            XCTAssertEqual(contact.x, crank.x, accuracy: 0.000001)
            XCTAssertEqual(contact.y, crank.y, accuracy: 0.000001)
            let forearm = try XCTUnwrap(scene.childNode(withName: "//part-2") as? SKSpriteNode)
            let wrist = forearm.convert(CGPoint(x: forearm.size.width * 102 / 133, y: forearm.size.height * 5 / 62), to: scene)
            XCTAssertEqual(hypot(wrist.x - contact.x, wrist.y - contact.y), 5, accuracy: 0.001)
        }
    }

    func testCharacterLocalArmStaysConnectedWhenTheBodyMovesOrMirrors() {
        let root = SKNode()
        let buddy = SKNode(); root.addChild(buddy)
        let arm = SKNode(); buddy.addChild(arm)
        for mirror in [CGFloat(-1), 1] {
            buddy.xScale = mirror; arm.xScale = mirror
            for offset in [CGFloat(-6), 0, 6] {
                buddy.position = CGPoint(x: 319, y: 134 + offset)
                let shoulder = buddy.convert(CGPoint(x: 29 * -mirror, y: 54), to: root)
                let pose = OperatorArmPose.connecting(shoulder: BubblePoint(x: shoulder.x, y: shoulder.y), hand: BubblePoint(x: 280, y: 191))
                let local = arm.convert(CGPoint(x: pose.shoulder.x, y: pose.shoulder.y), from: root)
                let drawn = arm.convert(local, to: root)
                XCTAssertEqual(drawn.x, shoulder.x, accuracy: 0.000001)
                XCTAssertEqual(drawn.y, shoulder.y, accuracy: 0.000001)
                XCTAssertEqual(hypot(pose.elbow.x - pose.shoulder.x, pose.elbow.y - pose.shoulder.y), OperatorArmPose.upperLength, accuracy: 0.000001)
            }
        }
    }
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
