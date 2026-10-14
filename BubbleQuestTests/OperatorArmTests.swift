import XCTest
import SpriteKit
@testable import BubbleQuest

final class OperatorArmTests: XCTestCase {
    @MainActor
    func testSteeringKeepsFixedLengthArmAndHandConnectedToBody() throws {
        let scene = FestivalScene(size: CGSize(width: 390, height: 844))
        scene.didMove(to: SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)))
        let wheel = try XCTUnwrap(scene.childNode(withName: "//handwheel"))
        let buddy = try XCTUnwrap(scene.childNode(withName: "//companion-1"))
        let arm = try XCTUnwrap(buddy.childNode(withName: "operator-arm"))
        let grip = try XCTUnwrap(arm.childNode(withName: "operator-grip"))
        let sleeve = try XCTUnwrap(arm.childNode(withName: "part-1") as? SKSpriteNode)
        let forearm = try XCTUnwrap(arm.childNode(withName: "part-2") as? SKSpriteNode)
        let sleeveSize = sleeve.size, forearmSize = forearm.size
        let firstHand = grip.convert(CGPoint.zero, to: scene)
        var motion: CGFloat = 0
        XCTAssertNil(wheel.childNode(withName: "crank"))
        XCTAssertTrue(grip.parent === arm)
        for step in -30...30 {
            wheel.zRotation = CGFloat(step) / 10
            scene.synchronizeOperatorRig()
            XCTAssertEqual(sleeve.size, sleeveSize)
            XCTAssertEqual(forearm.size, forearmSize)
            let elbow = sleeve.convert(CGPoint(x: sleeve.size.width * 121 / 153, y: -sleeve.size.height * 22 / 123), to: scene)
            let forearmStart = forearm.convert(CGPoint.zero, to: scene)
            XCTAssertEqual(elbow.x, forearmStart.x, accuracy: 0.001)
            XCTAssertEqual(elbow.y, forearmStart.y, accuracy: 0.001)
            let wrist = forearm.convert(CGPoint(x: forearm.size.width * 102 / 133, y: forearm.size.height * 5 / 62), to: scene)
            let hand = grip.convert(CGPoint.zero, to: scene)
            XCTAssertEqual(wrist.x, hand.x, accuracy: 0.001)
            XCTAssertEqual(wrist.y, hand.y, accuracy: 0.001)
            let palm = grip.convert(CGPoint(x: 19 * 32.0 / 72, y: 0), to: scene)
            let wheelCenter = wheel.convert(CGPoint.zero, to: scene)
            let palmRadius = hypot(palm.x - wheelCenter.x, palm.y - wheelCenter.y)
            XCTAssertGreaterThan(palmRadius, 18)
            XCTAssertLessThan(palmRadius, 23)
            motion = max(motion, hypot(hand.x - firstHand.x, hand.y - firstHand.y))
        }
        XCTAssertGreaterThan(motion, 5)
        let handBefore = grip.convert(CGPoint.zero, to: scene)
        buddy.position.x += 7
        let handAfter = grip.convert(CGPoint.zero, to: scene)
        XCTAssertEqual(handAfter.x - handBefore.x, 7, accuracy: 0.001)
    }

    @MainActor
    func testPuzzleMenuPausesWithoutRestartingAndBubbleIsSwapTarget() throws {
        let scene = FestivalScene(size: CGSize(width: 390, height: 844))
        scene.didMove(to: SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)))
        scene.closeMenu()
        let wheel = try XCTUnwrap(scene.childNode(withName: "//handwheel"))
        let game = try XCTUnwrap(wheel.parent)
        XCTAssertNil(game.childNode(withName: "home"))
        XCTAssertNil(game.childNode(withName: "retry"))
        XCTAssertNil(game.childNode(withName: "swap"))
        XCTAssertNil(game.childNode(withName: "next-caption"))
        let bubble = try XCTUnwrap(game.childNode(withName: "swap-bubble"))
        XCTAssertTrue(scene.interactionNames(at: bubble.convert(CGPoint.zero, to: scene)).contains("swap-bubble"))
        scene.showGameMenu()
        XCTAssertTrue(game.isPaused)
        scene.handleMenu(["game-resume"])
        XCTAssertFalse(game.isPaused)
        XCTAssertTrue(game.childNode(withName: "swap-bubble") === bubble)
    }
}
