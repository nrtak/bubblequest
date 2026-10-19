import Foundation

extension GameLevel {
    func objectiveHelp(board: BubbleBoard, goal: PuzzleGoal) -> String {
        var parts = [goal.kind.instruction]
        if goal.kind != .clear { parts.append("\(goal.remaining.count) of \(goal.total) objects still need freeing.") }
        if !board.armor.isEmpty { parts.append("Silver rings need two matches.") }
        if !board.blockers.isEmpty { parts.append("Wooden blocks can be dropped or bombed.") }
        parts.append("Bank-shot matches earn 50 extra points.")
        return parts.joined(separator: " ")
    }

    func retryHint(board: BubbleBoard, goal: PuzzleGoal, consecutiveLosses: Int) -> String? {
        guard consecutiveLosses >= 2 else { return nil }
        if !board.armor.isEmpty { return "Silver rings need two matches. Try clearing the bubbles supporting them." }
        if !board.blockers.isEmpty { return "Wooden blocks cannot be matched. Clear their supports or try a bomb." }
        switch goal.kind {
        case .lanterns, .charms:
            return "Only the glowing objects need rescuing. Drop their supports to free them."
        case .ceiling:
            return "Open one route upward. You only need the marked targets, not every bubble."
        case .clear:
            return isBankRoute ? "Bounce off a wall to reach behind the lower bubbles." : "Try dropping a branch by matching the bubbles that hold it up."
        }
    }
}

struct CourtyardPlaySummary {
    let runs: Int
    let wins: Int
    let savedShots: Int
    let boosters: Int
    let playedLevels: Int

    init(results: [LevelPlayResults]) {
        runs = results.reduce(0) { $0 + $1.completedRuns }
        wins = results.reduce(0) { $0 + $1.wins }
        savedShots = results.reduce(0) { $0 + $1.shotsSavedOnWins }
        boosters = results.reduce(0) { $0 + $1.boosterShots }
        playedLevels = results.filter { $0.completedRuns > 0 }.count
    }
    var winPercent: Int { runs == 0 ? 0 : wins * 100 / runs }
    var averageSaved: Int { wins == 0 ? 0 : savedShots / wins }
    var boostersPerRun: Double { runs == 0 ? 0 : Double(boosters) / Double(runs) }
}

/// Soften frequent cues while leaving celebration cues a little stronger.
enum FestivalSoundMix {
    static func effectVolume(name: String, requested: Float) -> Float {
        guard requested.isFinite else { return 0 }
        let gain: Float = ["victory", "milestone"].contains(name) ? 0.9 : 0.75
        return min(1, max(0, requested)) * gain
    }
}

enum PuzzleRating {
    static let maximumStars = 5
    static func minimumSaved(for stars: Int, budget: Int) -> Int {
        let budget = max(1, budget)
        switch stars {
        case 5: return max(1, budget / 2)
        case 4: return max(1, budget * 3 / 8)
        case 3: return max(1, budget / 4)
        case 2: return max(1, budget / 8)
        default: return 0
        }
    }
    static func fiveStarHint(budget: Int) -> String {
        "Save \(minimumSaved(for: 5, budget: budget)) shots for 5 stars."
    }
    static func stars(shotsRemaining: Int, budget: Int) -> Int {
        let budget = max(1, budget)
        if shotsRemaining >= minimumSaved(for: 5, budget: budget) { return 5 }
        if shotsRemaining >= minimumSaved(for: 4, budget: budget) { return 4 }
        if shotsRemaining >= minimumSaved(for: 3, budget: budget) { return 3 }
        if shotsRemaining >= minimumSaved(for: 2, budget: budget) { return 2 }
        return 1
    }
}
