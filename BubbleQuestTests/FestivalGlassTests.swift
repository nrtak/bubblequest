import XCTest
import SpriteKit
import UIKit
@testable import BubbleQuest

final class FestivalGlassTests: XCTestCase {
    func testGlassIsLimitedToNavigationAndHonorsAccessibilityAndPreference() {
        for menu in ["title", "map", "settings", "control-settings", "sound-levels"] {
            XCTAssertTrue(FestivalGlassPolicy.enabled(menu: menu, preference: true, reduceTransparency: false, highContrast: false))
            XCTAssertFalse(FestivalGlassPolicy.enabled(menu: menu, preference: false, reduceTransparency: false, highContrast: false))
            XCTAssertFalse(FestivalGlassPolicy.enabled(menu: menu, preference: true, reduceTransparency: true, highContrast: false))
            XCTAssertFalse(FestivalGlassPolicy.enabled(menu: menu, preference: true, reduceTransparency: false, highContrast: true))
        }
        for menu in ["game", "level-briefing", "quest", "ending", "map-buddies"] {
            XCTAssertFalse(FestivalGlassPolicy.enabled(menu: menu, preference: true, reduceTransparency: false, highContrast: false))
        }
    }

    @MainActor
    private func withHost(_ check: (FestivalScene, FestivalGlassHost, GameProfiles) throws -> Void) throws {
        try XCTSkipIf(UIAccessibility.isReduceTransparencyEnabled || UIAccessibility.isDarkerSystemColorsEnabled,
                      "System accessibility preferences intentionally use the classic presentation")
        let suite = "FestivalGlass-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let host = FestivalGlassHost(scene: scene)
        host.frame = CGRect(x: 0, y: 0, width: 390, height: 844); host.layoutIfNeeded()
        scene.refreshGlassPresentation()
        defer { host.detach() }
        try check(scene, host, profiles)
    }

    @MainActor
    func testNativeGlassDoesNotReplaceSharpTextOrExistingTouchTargets() throws {
        try withHost { scene, host, _ in
            XCTAssertTrue(host.isPresentingGlass)
            XCTAssertEqual(host.surfaceCount, 4)
            XCTAssertEqual(host.artworkCount, 1)
            let panel = try XCTUnwrap(scene.childNode(withName: "//continue-panel") as? SKShapeNode)
            XCTAssertEqual(panel.fillColor.cgColor.alpha, 0)
            XCTAssertNotNil(scene.childNode(withName: "//welcome-player") as? SKLabelNode)
            XCTAssertNotNil(scene.childNode(withName: "//title-illustration") as? SKSpriteNode)
            XCTAssertTrue(scene.interactionNames(at: CGPoint(x: 151, y: 230)).contains("players"))
            XCTAssertTrue(scene.interactionNames(at: CGPoint(x: 315, y: 230)).contains("settings"))
            XCTAssertTrue(scene.interactionNames(at: CGPoint(x: 195, y: 410)).contains("start-continue"))
            XCTAssertTrue(host.subviews.last === host.spriteView)
            let hit = host.hitTest(CGPoint(x: 195, y: 434), with: nil)
            XCTAssertTrue(hit === host.spriteView || hit?.isDescendant(of: host.spriteView) == true)
            let native = host.subviews.flatMap(\.subviews).compactMap { $0 as? UIVisualEffectView }
            XCTAssertEqual(native.count, 4)
            if #available(iOS 26.0, *) { XCTAssertTrue(native.allSatisfy { $0.effect is UIGlassEffect }) }
            else { XCTAssertTrue(native.allSatisfy { $0.effect is UIBlurEffect }) }
            scene.refreshGlassPresentation()
            let refreshed = host.subviews.flatMap(\.subviews).compactMap { $0 as? UIVisualEffectView }
            XCTAssertEqual(native.map(ObjectIdentifier.init), refreshed.map(ObjectIdentifier.init), "Do not rebuild glass every frame")
        }
    }

    @MainActor
    func testGlassSwitchPersistsAndRestoresClassicArtworkAndPanels() throws {
        try withHost { scene, host, profiles in
            XCTAssertTrue(profiles.makeProgress().enabled(.glass))
            scene.handleMenu(["settings"]); scene.handleMenu(["control-settings"])
            scene.refreshGlassPresentation()
            XCTAssertNotNil(scene.childNode(withName: "//setting-glassMenusEnabled"))
            scene.handleMenu(["setting-glassMenusEnabled"]); scene.refreshGlassPresentation()
            XCTAssertFalse(profiles.makeProgress().enabled(.glass))
            XCTAssertFalse(host.isPresentingGlass); XCTAssertEqual(host.surfaceCount, 0); XCTAssertEqual(host.artworkCount, 0)
            scene.handleMenu(["home"]); scene.refreshGlassPresentation()
            let panel = try XCTUnwrap(scene.childNode(withName: "//continue-panel") as? SKShapeNode)
            XCTAssertNotNil(panel.fillTexture); XCTAssertGreaterThan(panel.fillColor.cgColor.alpha, 0.9)
            XCTAssertFalse(try XCTUnwrap(scene.childNode(withName: "//title-illustration")).isHidden)
            scene.handleMenu(["settings"]); scene.handleMenu(["control-settings"])
            scene.handleMenu(["setting-glassMenusEnabled"]); scene.refreshGlassPresentation()
            XCTAssertTrue(host.isPresentingGlass)
            scene.handleMenu(["setting-highContrastEnabled"]); scene.refreshGlassPresentation()
            XCTAssertFalse(host.isPresentingGlass)
        }
    }

    @MainActor
    func testNativeMapArtworkMovesWithTheStreetAndStaysBounded() throws {
        try withHost { scene, host, _ in
            scene.handleMenu(["start-adventure"]); scene.refreshGlassPresentation()
            let route = try XCTUnwrap(scene.childNode(withName: "//map-route"))
            let image = try XCTUnwrap(host.subviews.first?.subviews.compactMap { $0 as? UIImageView }.first)
            let before = image.frame.minY
            let stop = try XCTUnwrap(scene.childNode(withName: "//level-0"))
            let markerBefore = scene.convertPoint(toView: stop.convert(CGPoint.zero, to: scene)).y
            scene.scrollMap(to: route.position.y - 20); scene.refreshGlassPresentation()
            let markerAfter = scene.convertPoint(toView: stop.convert(CGPoint.zero, to: scene)).y
            XCTAssertEqual(image.frame.minY - before, markerAfter - markerBefore, accuracy: 0.01)
            for level in stride(from: 0, through: 219, by: 17) {
                scene.scrollMap(to: FestivalMapLayout.focusedOffset(local: level)); scene.refreshGlassPresentation()
                XCTAssertLessThanOrEqual(host.artworkCount, 5)
                XCTAssertLessThanOrEqual(host.surfaceCount, 6)
            }
            scene.closeMenu(); scene.refreshGlassPresentation()
            XCTAssertFalse(host.isPresentingGlass); XCTAssertEqual(host.artworkCount, 0); XCTAssertEqual(host.surfaceCount, 0)
            XCTAssertNotNil(scene.childNode(withName: "//rainbow"))
        }
    }

    @MainActor
    func testLeavingGlassMapKeepsTheStreetInTheLevelBriefingSnapshot() throws {
        try withHost { scene, host, _ in
            scene.handleMenu(["start-adventure"]); scene.refreshGlassPresentation()
            XCTAssertGreaterThan(host.artworkCount, 0)
            scene.handleMenu(["level-0"]); scene.refreshGlassPresentation()
            XCTAssertEqual(host.artworkCount, 0)
            let card = try XCTUnwrap(scene.childNode(withName: "//level-briefing-card"))
            let background = try XCTUnwrap(card.parent?.children.first as? SKSpriteNode)
            let image = try XCTUnwrap(background.texture).cgImage()
            let sample = try XCTUnwrap(image.cropping(to: CGRect(x: CGFloat(image.width) * 0.9,
                                                                 y: CGFloat(image.height) * 0.5, width: 1, height: 1)))
            var pixel = [UInt8](repeating: 0, count: 4)
            pixel.withUnsafeMutableBytes { bytes in
                let context = CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                                        bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
                context?.draw(sample, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            }
            XCTAssertGreaterThan(pixel[3], 200, "The walking street must remain behind the briefing")
        }
    }

    func testGlassPreferenceDefaultsOnAndIsIncludedInPlayerBackup() throws {
        let suite = "GlassPreference-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress()
        XCTAssertTrue(progress.enabled(.glass)); progress.toggle(.glass)
        XCTAssertFalse(GameProgress(defaults: defaults).enabled(.glass))
        XCTAssertTrue(profiles.persistActive())
        let data = try Data(contentsOf: directory.appendingPathComponent(profiles.active.fileName))
        let saved = try XCTUnwrap(try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any])
        XCTAssertEqual(saved[GameSetting.glass.rawValue] as? Bool, false)
    }
}
