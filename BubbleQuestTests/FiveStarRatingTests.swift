import XCTest
@testable import BubbleQuest

final class FiveStarRatingTests: XCTestCase {
    func testFiveDistinctRatingsAndMaximumAcrossShotBudgets() {
        for (remaining, expected) in [(0, 1), (2, 2), (4, 3), (6, 4), (8, 5)] {
            XCTAssertEqual(PuzzleRating.stars(shotsRemaining: remaining, budget: 16), expected)
        }
        for budget in 12...100 {
            let ratings = (0...budget).map { PuzzleRating.stars(shotsRemaining: $0, budget: budget) }
            XCTAssertTrue(ratings.allSatisfy { (1...5).contains($0) })
            XCTAssertEqual(ratings, ratings.sorted())
            XCTAssertEqual(ratings.last, 5)
            XCTAssertEqual(Set(ratings), Set(1...5))
        }
        XCTAssertEqual(LevelCatalog.maximumStars, 1100)
    }

    func testOldRatingsConvertOnceAndNewFourStarRatingsStayFour() {
        let suite = "FiveStarMigration-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(1, forKey: "stars-0")
        defaults.set(2, forKey: "stars-1")
        defaults.set(3, forKey: "stars-2")
        defaults.set(900, forKey: "bestScore-2")
        let progress = GameProgress(defaults: defaults)
        XCTAssertEqual((0..<3).map(progress.stars), [1, 3, 5])
        XCTAssertEqual(progress.bestScore(2), 900)
        progress.recordVictory(index: 3, score: 100, stars: 4)
        let reopened = GameProgress(defaults: defaults)
        XCTAssertEqual((0..<4).map(reopened.stars), [1, 3, 5, 4])
        XCTAssertEqual(defaults.integer(forKey: "starRatingVersion"), 1)
    }

    func testLegacyTopRatingMedalsRemainOwnedAndNewAwardsNeedFiveStars() throws {
        let old = Data("[\"threeStars\"]".utf8)
        XCTAssertEqual(try JSONDecoder().decode(Set<ChallengeMedal>.self, from: old), [.fiveStars])
        XCTAssertFalse(ChallengeMedal.earned(stars: 3, boosters: 1, bankMatches: 0).contains(.fiveStars))
        XCTAssertTrue(ChallengeMedal.earned(stars: 5, boosters: 1, bankMatches: 0).contains(.fiveStars))
    }

    func testTargetWinsExplainLeftoverBubblesWhileClearLevelsRequireAnEmptyBoard() {
        let target = Cell(row: 0, column: 0)
        let board = BubbleBoard(bubbles: [Cell(row: 0, column: 7): 0])
        var goal = PuzzleGoal(kind: .ceiling, targets: [target])
        goal.collect([target])
        XCTAssertTrue(goal.completed(on: board))
        XCTAssertTrue(goal.startSummary.contains("Other bubbles can stay"))
        XCTAssertTrue(goal.victorySummary(on: board).contains("1 other bubble didn't need clearing"))
        XCTAssertFalse(PuzzleGoal().completed(on: board))
        XCTAssertTrue(PuzzleGoal().completed(on: BubbleBoard()))
        XCTAssertEqual(PuzzleGoal().startSummary, "Clear every bubble to win.")
    }
    func testDisplayedStarThresholdMatchesTheAwardAtEveryBudget() {
        for budget in 12...100 {
            for rating in 2...5 {
                let minimum = PuzzleRating.minimumSaved(for: rating, budget: budget)
                XCTAssertGreaterThanOrEqual(PuzzleRating.stars(shotsRemaining: minimum, budget: budget), rating)
                XCTAssertLessThan(PuzzleRating.stars(shotsRemaining: minimum - 1, budget: budget), rating)
            }
            XCTAssertEqual(PuzzleRating.fiveStarHint(budget: budget), "Save \(budget / 2) shots for 5 stars.")
        }
    }

}
