import XCTest
import SpriteKit
@testable import BubbleQuest

final class OperatorArmTests: XCTestCase {
    @MainActor
    func testShortArmRestsOnStationaryRimAcrossWheelRotations() throws {
        let scene = FestivalScene(size: CGSize(width: 390, height: 844))
        scene.didMove(to: SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)))
        let wheel = try XCTUnwrap(scene.childNode(withName: "//handwheel"))
        let knob = try XCTUnwrap(scene.childNode(withName: "//rim-contact"))
        let grip = try XCTUnwrap(knob.childNode(withName: "operator-grip"))
        XCTAssertTrue(grip.parent === knob)
        wheel.parent?.isPaused = false
        let firstGrip = grip.convert(CGPoint.zero, to: scene)
        let firstForearm = try XCTUnwrap(scene.childNode(withName: "//part-2") as? SKSpriteNode)
        let fixedSize = firstForearm.size
        for step in -30...30 {
            wheel.zRotation = CGFloat(step) / 10
            scene.didFinishUpdate()
            let contact = grip.convert(CGPoint.zero, to: scene)
            let crank = knob.convert(CGPoint.zero, to: scene)
            XCTAssertEqual(contact.x, crank.x, accuracy: 0.000001)
            XCTAssertEqual(contact.y, crank.y, accuracy: 0.000001)
            XCTAssertEqual(contact.x, firstGrip.x, accuracy: 0.000001)
            XCTAssertEqual(contact.y, firstGrip.y, accuracy: 0.000001)
            let forearm = try XCTUnwrap(scene.childNode(withName: "//part-2") as? SKSpriteNode)
            XCTAssertEqual(forearm.size, fixedSize)
            let wrist = forearm.convert(CGPoint(x: forearm.size.width * 102 / 133, y: forearm.size.height * 5 / 62), to: scene)
            XCTAssertEqual(hypot(wrist.x - contact.x, wrist.y - contact.y), 5, accuracy: 0.001)
        }
    }

}
