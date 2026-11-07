import XCTest
import SpriteKit
import UIKit
@testable import BubbleQuest

final class FestivalProjectTests: XCTestCase {
    func testStoriesAndSilhouettesChangeWithTheNeighborhoodAndPreparation() throws {
        let styles = Set(FestivalProject.all.map { String(describing: $0.displayStyle) })
        XCTAssertGreaterThanOrEqual(styles.count, 6)
        for project in FestivalProject.all {
            XCTAssertEqual(project.story(stage: 0), project.invitation)
            let lines = (1...4).map { project.story(stage: $0) }
            XCTAssertEqual(Set(lines).count, 4)
            XCTAssertTrue(lines.allSatisfy { !$0.isEmpty && $0.count < 110 })
            XCTAssertEqual(project.story(stage: 99), project.story(stage: 4))
        }
        XCTAssertEqual(FestivalProject.forArea(7)?.title, "Shota's kite parade")
    }

    @MainActor
    func testCompletedProjectsKeepTheirStoryArtWithinTheCardAndRoadsideConstructionOnTheMap() throws {
        try withScene(configure: { progress in
            for index in 0..<160 { progress.recordVictory(index: index, score: 100, stars: 1) }
        }) { scene, _ in
            for (area, feature) in [(1, "pinwheels"), (2, "lanternWalk"), (3, "picnic"), (7, "kites")] {
                scene.handleMenu(["start-adventure"])
                scene.scrollMap(to: FestivalMapLayout.focusedOffset(local: area * 20))
                scene.handleMenu(["map-journey-header"])
                let display = try XCTUnwrap(scene.childNode(withName: "//project-story-illustration"))
                let frame = display.calculateAccumulatedFrame()
                XCTAssertGreaterThanOrEqual(frame.minY, 355)
                XCTAssertLessThanOrEqual(frame.maxY, 515, "Leave room for the progress text")
                XCTAssertGreaterThanOrEqual(frame.minX, 36)
                XCTAssertLessThanOrEqual(frame.maxX, 354)
                scene.handleMenu(["project-back"])
                XCTAssertNotNil(scene.childNode(withName: "//project-feature-" + feature))
            }
        }
    }

    @MainActor
    func testEveryNeighborhoodShipsItsOwnWideStoryIllustration() throws {
        XCTAssertEqual(Set(FestivalProject.all.map(\.illustrationName)).count, 11)
        for project in FestivalProject.all {
            let image = try XCTUnwrap(UIImage(named: project.illustrationName + ".jpg"), project.illustrationName)
            XCTAssertEqual(image.size.width / image.size.height, 2, accuracy: 0.001)
            XCTAssertGreaterThanOrEqual(image.size.width * image.scale, 954, "Fit a three-times-resolution project card")
        }
    }

    @MainActor
    func testIllustratedFinaleBriefingKeepsInstructionsAndPlaySeparateFromTheArt() throws {
        try withScene(configure: { progress in
            for index in 0..<LevelCatalog.levelCount { progress.recordVictory(index: index, score: 100, stars: 1) }
        }) { scene, profiles in
            scene.handleMenu(["start-adventure"])
            for project in FestivalProject.all {
                scene.handleMenu(["level-\(project.finaleLevel)"])
                let art = try XCTUnwrap(scene.childNode(withName: "//briefing-story-illustration"))
                let artFrame = art.calculateAccumulatedFrame()
                let summary = try XCTUnwrap(scene.childNode(withName: "//briefing-objective-summary"))
                XCTAssertEqual(artFrame.width / artFrame.height, 2, accuracy: 0.001)
                XCTAssertGreaterThanOrEqual(artFrame.minY, 488)
                XCTAssertLessThanOrEqual(artFrame.maxY, 638)
                XCTAssertLessThan(summary.calculateAccumulatedFrame().maxY, 450, "Leave room for the mission heading")
                XCTAssertGreaterThan(summary.calculateAccumulatedFrame().minY, 366, "Keep instructions above the shot count")
                XCTAssertNotNil(scene.childNode(withName: "//briefing-play"))
                XCTAssertNil(scene.childNode(withName: "//flying-bubble"))
                XCTAssertEqual(profiles.makeProgress().lives(for: project.finaleLevel).available, 5)
                scene.handleMenu(["briefing-back"])
            }
        }
    }

    func testProjectsCoverTheWholeJourneyAndLinkToAuthoredFinales() {
        XCTAssertEqual(FestivalProject.all.count, LevelCatalog.areas.count)
        XCTAssertEqual(FestivalProject.all.flatMap { Array($0.levels) }, Array(0..<LevelCatalog.levelCount))
        XCTAssertEqual(FestivalProject.thresholds, [5, 10, 15, 20])
        for project in FestivalProject.all {
            XCTAssertTrue(LevelCatalog.level(project.finaleLevel).isMilestone)
            XCTAssertEqual(LevelCatalog.level(project.finaleLevel).objective, FestivalEvent.forLevel(project.finaleLevel)?.objective)
            for step in 0..<4 {
                let site = project.sitePosition(stage: step)
                let marker = FestivalMapLayout.position(project.levels.lowerBound + FestivalProject.thresholds[step] - 1)
                XCTAssertGreaterThan(abs(site.x - marker.x), 90)
            }
        }
    }

    func testOnlyDistinctCampaignClearsAdvancePreparation() throws {
        try withProgress { progress, _ in
            XCTAssertEqual(progress.festivalProject(area: 0)?.stage, 0)
            for index in 0..<5 { progress.recordVictory(index: index, score: 100, stars: 1) }
            for _ in 0..<8 { progress.recordVictory(index: 0, score: 200, stars: 5) }
            XCTAssertEqual(progress.festivalProject(area: 0)?.cleared, 5)
            XCTAssertEqual(progress.festivalProject(area: 0)?.stage, 1)
            XCTAssertEqual(progress.festivalProject(area: 0)?.nextThreshold, 10)
            XCTAssertEqual(progress.festivalProject(area: 1)?.cleared, 0)
            XCTAssertFalse(progress.claimProjectReward(area: 0))
            XCTAssertEqual(progress.adventure.rainbowGifts, 0)
            XCTAssertNil(progress.festivalProject(area: -1))
            XCTAssertFalse(progress.claimProjectReward(area: 11))
        }
    }

    func testAProjectRequiresAllItsLevelsAndPaysOnceAcrossReopening() throws {
        try withProgress { progress, defaults in
            for index in 0..<19 { progress.recordVictory(index: index, score: 100, stars: 1) }
            XCTAssertFalse(progress.claimProjectReward(area: 0))
            progress.recordVictory(index: 19, score: 100, stars: 1)
            XCTAssertTrue(progress.claimProjectReward(area: 0))
            XCTAssertEqual(progress.adventure.rainbowGifts, 1)
            XCTAssertEqual(progress.adventure.bombGifts, 1)
            let reopened = GameProgress(defaults: defaults)
            XCTAssertFalse(reopened.claimProjectReward(area: 0))
            XCTAssertEqual(reopened.adventure.rainbowGifts, 1)
            XCTAssertTrue(try XCTUnwrap(reopened.festivalProject(area: 0)).rewardCollected)
            XCTAssertEqual(reopened.festivalProject(area: 0)?.stage, 4)
        }
    }

    func testOldAdventureDataKeepsItsQuestsWhenProjectLedgerIsAbsent() throws {
        try withProgress { progress, defaults in
            let quest = FestivalQuest.all[0]
            progress.adventure.accept(quest, unlockedLevel: 3)
            let data = try XCTUnwrap(defaults.data(forKey: "festivalAdventure"))
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            object.removeValue(forKey: "projectRewards")
            defaults.set(try JSONSerialization.data(withJSONObject: object), forKey: "festivalAdventure")
            let restored = GameProgress(defaults: defaults)
            XCTAssertTrue(restored.adventure.accepted(quest))
            XCTAssertFalse(restored.adventure.hasProjectReward(0))
        }
    }

    @MainActor
    func testMapProjectLeadsToExplicitPlayAndDoesNotAcceptSideQuests() throws {
        try withScene { scene, profiles in
            scene.handleMenu(["start-adventure"])
            let header = try XCTUnwrap(scene.childNode(withName: "//map-journey-header"))
            XCTAssertTrue(scene.interactionNames(at: header.position).contains("map-journey-header"))
            scene.handleMenu(["map-journey-header"])
            XCTAssertNotNil(scene.childNode(withName: "//project-story-illustration"))
            XCTAssertNotNil(scene.childNode(withName: "//project-play"))
            scene.handleMenu(["project-play"])
            XCTAssertNotNil(scene.childNode(withName: "//level-briefing-card"))
            XCTAssertFalse(profiles.makeProgress().adventure.accepted(FestivalQuest.all[0]))
            XCTAssertEqual(profiles.makeProgress().lives(for: 0).available, 5)
        }
    }

    @MainActor
    func testFinaleOpensTheCelebrationAndDoesNotPayForRevisiting() throws {
        try withScene(configure: { progress in
            for index in 0..<19 { progress.recordVictory(index: index, score: 100, stars: 1) }
            let board = BubbleBoard(bubbles: [Cell(row: 0, column: 3): 0, Cell(row: 0, column: 4): 0])
            progress.save(GameCheckpoint(level: 19, board: board, shots: 20, score: 0, current: 0, next: 1,
                                         bag: [], rainbow: 1, bomb: 1, play: QuestPlay(), goal: PuzzleGoal()))
        }) { scene, profiles in
            scene.handleMenu(["start-continue"]); scene.handleMenu(["briefing-play"])
            scene.launchShot(angle: 0); scene.setActive(false); scene.setActive(true)
            XCTAssertEqual(profiles.makeProgress().adventure.rainbowGifts, 1)
            XCTAssertEqual(profiles.makeProgress().adventure.bombGifts, 1)
            scene.continueAfterResult()
            XCTAssertNotNil(scene.childNode(withName: "//project-story-illustration"))
            scene.handleMenu(["project-back"])
            scene.scrollMap(to: FestivalMapLayout.focusedOffset(local: 0))
            scene.handleMenu(["map-journey-header"])
            XCTAssertEqual(profiles.makeProgress().adventure.rainbowGifts, 1)
        }
    }

    private func withProgress(_ check: (GameProgress, UserDefaults) throws -> Void) throws {
        let suite = "FestivalProject-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try check(GameProgress(defaults: defaults), defaults)
    }

    @MainActor
    private func withScene(configure: (GameProgress) throws -> Void = { _ in },
                           check: (FestivalScene, GameProfiles) throws -> Void) throws {
        let suite = "ProjectScene-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress(); progress.tutorialSeen = true; progress.practiceDone = true
        try configure(progress)
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene); defer { view.presentScene(nil) }
        try check(scene, profiles)
    }
}
