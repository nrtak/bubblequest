import XCTest
import SpriteKit
@testable import BubbleQuest

final class OperatorArmTests: XCTestCase {
    func testEveryOperatorBendsOutsideTorsoAndPaintedPalmTouchesRim() {
        let boundaries = [0.0, 223, 435, 654, 876, 1099, 1326, 1550, 1774]
        let sockets = [(192.0, 128.0), (183, 344), (188, 562), (194, 785),
                       (197, 1009), (194, 1232), (195, 1456), (194, 1680)]
        for (row, socket) in sockets.enumerated() {
            let shoulder = BubblePoint(x: 319 - ((socket.0 - 9 - 35) / 215 - 0.5) * 125,
                                       y: 134 + (boundaries[row + 1] - socket.1 + 12) / (boundaries[row + 1] - boundaries[row]) * 125)
            for step in -30...30 {
                let stroke = -0.65 + max(-0.2, min(0.2, Double(step) / 10 * 0.08))
                let contact = BubblePoint(x: 280 + cos(stroke) * 21, y: 173 + sin(stroke) * 21)
                let pose = OperatorArmPose.gripping(shoulder: shoulder, hand: contact, palmLength: OperatorArmPose.palmLength)
                XCTAssertLessThan(pose.elbow.x, shoulder.x, "Operator \(row) folds across the torso")
                XCTAssertLessThan(pose.elbow.y, shoulder.y)
                XCTAssertEqual(hypot(pose.elbow.x - shoulder.x, pose.elbow.y - shoulder.y), 18, accuracy: 0.001)
                let dx = pose.hand.x - pose.elbow.x, dy = pose.hand.y - pose.elbow.y
                XCTAssertEqual(hypot(dx, dy), 18, accuracy: 0.001)
                let palmX = pose.hand.x + dx / 18 * OperatorArmPose.palmLength
                let palmY = pose.hand.y + dy / 18 * OperatorArmPose.palmLength
                XCTAssertEqual(palmX, contact.x, accuracy: 0.001)
                XCTAssertEqual(palmY, contact.y, accuracy: 0.001)
            }
        }
    }

    @MainActor
    func testSteeringKeepsFixedLengthArmAndHandConnectedToBody() throws {
        let suite = "OperatorArms-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress()
        for level in 0..<200 { progress.recordVictory(index: level, score: 200, stars: 1) }
        for quest in FestivalQuest.all {
            progress.adventure.accept(quest, unlockedLevel: 199)
            var play = QuestPlay()
            play.collected.insert(quest.id); play.bounces = 1; play.dropped = 1
            play.colors = Set(0..<6)
            for level in quest.area * 10..<quest.area * 10 + quest.steps.count {
                progress.adventure.recordWin(level: level, play: play, completedLevels: 200)
            }
        }
        for friend in Companion.all where friend.kind == .human {
            progress.select(friend)
            XCTAssertEqual(progress.selected(.human).id, friend.id)
            let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
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
            XCTAssertEqual(arm.zPosition, 0)
            XCTAssertLessThan(sleeve.zPosition, 0, "The body must cover the sleeve's open shoulder edge")
            XCTAssertGreaterThan(forearm.zPosition, 0)
            for step in -30...30 {
                wheel.zRotation = CGFloat(step) / 10
                scene.synchronizeOperatorRig()
                XCTAssertEqual(sleeve.size, sleeveSize)
                XCTAssertEqual(forearm.size, forearmSize)
                let elbow = sleeve.convert(CGPoint(x: sleeve.size.width * 121 / 153, y: -sleeve.size.height * 22 / 123), to: scene)
                let forearmStart = forearm.convert(CGPoint.zero, to: scene)
                let shoulder = sleeve.convert(CGPoint.zero, to: scene)
                XCTAssertLessThan(forearmStart.x, shoulder.x, "\(friend.id): elbow must stay on the wheel side of the torso")
                XCTAssertLessThan(forearmStart.y, shoulder.y)
                XCTAssertEqual(elbow.x, forearmStart.x, accuracy: 0.001)
                XCTAssertEqual(elbow.y, forearmStart.y, accuracy: 0.001)
                let wrist = forearm.convert(CGPoint(x: forearm.size.width * 102 / 133, y: forearm.size.height * 5 / 62), to: scene)
                let hand = grip.convert(CGPoint.zero, to: scene)
                XCTAssertEqual(wrist.x, hand.x, accuracy: 0.001)
                XCTAssertEqual(wrist.y, hand.y, accuracy: 0.001)
                let palm = grip.convert(CGPoint(x: 19 * 32.0 / 72, y: 0), to: scene)
                let wheelCenter = wheel.convert(CGPoint.zero, to: scene)
                let palmRadius = hypot(palm.x - wheelCenter.x, palm.y - wheelCenter.y)
                XCTAssertEqual(palmRadius, 21, accuracy: 0.001, friend.id)
                motion = max(motion, hypot(hand.x - firstHand.x, hand.y - firstHand.y))
            }
            XCTAssertGreaterThan(motion, 2.5, friend.id)
            let handBefore = grip.convert(CGPoint.zero, to: scene)
            buddy.position.x += 7
            let handAfter = grip.convert(CGPoint.zero, to: scene)
            XCTAssertEqual(handAfter.x - handBefore.x, 7, accuracy: 0.001)
        }
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
