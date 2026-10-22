import Foundation

enum PuzzleObjective: String, Codable {
    case clear, lanterns, charms, ceiling

    var title: String {
        switch self {
        case .clear: return "Clear the board"
        case .lanterns: return "Rescue the lanterns"
        case .charms: return "Collect the charms"
        case .ceiling: return "Reach the targets"
        }
    }
    var completionTitle: String {
        switch self {
        case .clear: return "Board cleared!"
        case .lanterns: return "Lanterns rescued!"
        case .charms: return "Charms collected!"
        case .ceiling: return "Targets reached!"
        }
    }
    var symbol: String {
        switch self {
        case .clear: return "sparkles"
        case .lanterns: return "lightbulb.fill"
        case .charms: return "gift.fill"
        case .ceiling: return "scope"
        }
    }
    var hudTitle: String {
        switch self {
        case .clear: return "Clear every bubble"
        case .lanterns: return "Rescue lanterns"
        case .charms: return "Collect charms"
        case .ceiling: return "Clear marked targets"
        }
    }
    func targetNoun(count: Int) -> String {
        switch self {
        case .clear: return count == 1 ? "bubble" : "bubbles"
        case .lanterns: return count == 1 ? "lantern" : "lanterns"
        case .charms: return count == 1 ? "charm" : "charms"
        case .ceiling: return count == 1 ? "marked target" : "marked targets"
        }
    }
    var instruction: String {
        self == .clear ? "Match bubbles or remove their supports to clear the board." :
            "Free every object inside a glowing bubble: match its color or remove its supports. The other bubbles can stay."
    }
}

struct PuzzleGoal: Codable, Equatable {
    let kind: PuzzleObjective
    let total: Int
    private(set) var remaining: Set<Cell>

    init(kind: PuzzleObjective = .clear, targets: Set<Cell> = []) {
        self.kind = kind; total = targets.count; remaining = targets
    }
    var startSummary: String {
        guard kind != .clear else { return "Clear every bubble to win." }
        let verb = kind == .lanterns ? "Rescue" : kind == .charms ? "Collect" : "Clear"
        return "\(verb) \(total) \(kind.targetNoun(count: total)) to win.\nOther bubbles can stay."
    }
    func victorySummary(on board: BubbleBoard) -> String {
        guard kind != .clear else { return "Every bubble cleared!" }
        let verb = kind == .lanterns ? "rescued" : kind == .charms ? "collected" : "cleared"
        let noun = board.bubbles.count == 1 ? "bubble" : "bubbles"
        let leftovers = board.bubbles.isEmpty ? "" : "\n\(board.bubbles.count) other \(noun) didn't need clearing."
        let objects = total == 1 ? "The \(kind.targetNoun(count: total))" : "All \(total) \(kind.targetNoun(count: total))"
        return "\(objects) \(verb)!" + leftovers
    }
    mutating func collect(_ removed: Set<Cell>) { remaining.subtract(removed) }
    func completed(on board: BubbleBoard) -> Bool {
        kind == .clear ? board.bubbles.isEmpty : remaining.isEmpty
    }
    var progressText: String { kind == .clear ? kind.title : "\(kind.title) \(total - remaining.count)/\(total)" }
    func isValid(on board: BubbleBoard) -> Bool {
        total >= remaining.count && total <= 8 && remaining.isSubset(of: Set(board.bubbles.keys)) &&
            (kind == .clear ? total == 0 : total > 0)
    }
}

extension GameLevel {
    var isBankRoute: Bool { index >= 10 && index % 10 == 3 }
    var isMilestone: Bool { number.isMultiple(of: LevelCatalog.levelsPerArea) }
    var objective: PuzzleObjective {
        if index < 5 { return .clear }
        if isMilestone { return .ceiling }
        switch index % 10 {
        case 4: return .lanterns
        case 6: return .charms
        case 7: return .ceiling
        default: return .clear
        }
    }
    var goal: PuzzleGoal {
        guard objective != .clear else { return PuzzleGoal() }
        let ordered = initialBubbles.keys.sorted {
            if $0.row != $1.row { return $0.row < $1.row }
            return $0.column < $1.column
        }
        // Rescue objects sit inside the board, behind lower supporting layers.
        let depth = initialBubbles.keys.map(\.row).max() ?? 0
        let upperRescueRow = index >= 20 ? max(1, depth / 2) : max(1, depth - 1)
        let buried = ordered.filter { $0.row > 0 && $0.row <= upperRescueRow }
        let candidates = objective == .ceiling ? ordered.filter { $0.row == 0 } : (buried.isEmpty ? ordered : buried)
        // Reaching the ceiling should leave non-target supports worth planning around.
        let targetCount = objective == .ceiling ? (isMilestone ? 4 : min(5, 3 + index / 100)) : min(7, (objective == .charms ? 4 : 3) + index / 60)
        let count = min(candidates.count, targetCount)
        var targets = Set<Cell>()
        for index in 0..<count {
            if objective == .ceiling || self.index < 20 {
                targets.insert(candidates[index * candidates.count / count])
            } else {
                // Separate rescue routes across the width of the board, instead
                // of grouping all prizes near an exposed edge or one bomb radius.
                let column = (2 * index + 1) * BubbleBoard.columns / (2 * count)
                let row = 1 + index % min(2, upperRescueRow)
                let choice = candidates.filter { !targets.contains($0) }.min { a, b in
                    let da = abs(a.row - row) * 8 + abs(a.column - column)
                    let db = abs(b.row - row) * 8 + abs(b.column - column)
                    return da == db ? (a.row == b.row ? a.column < b.column : a.row < b.row) : da < db
                }
                if let choice { targets.insert(choice) }
            }
        }
        return PuzzleGoal(kind: objective, targets: targets)
    }
    var initialArmor: Set<Cell> {
        guard index >= 20, ([2, 9].contains(index % 10) || [.lanterns, .charms].contains(objective)) else { return [] }
        let excluded = Set(initialSpecials.keys).union(goal.remaining)
        let targetRow = goal.remaining.map(\.row).max() ?? 0
        let candidates = initialBubbles.keys.filter { $0.row > 0 && !excluded.contains($0) }
            .sorted { a, b in
                let da = abs(a.row - targetRow - 1), db = abs(b.row - targetRow - 1)
                return da == db ? (a.row == b.row ? a.column < b.column : a.row < b.row) : da < db
            }
        // Finale targets already require reaching the ceiling through a deep board.
        // Leave openings around their supports instead of forming an armored wall.
        let armorLimit = isMilestone ? 3 : 5
        return Set(candidates.prefix(min(armorLimit, 1 + index / 45)))
    }
    var initialBlockers: Set<Cell> {
        guard index >= 40, [3, 8, 9].contains(index % 10) else { return [] }
        let excluded = Set(initialSpecials.keys).union(initialArmor).union(goal.remaining)
        let candidates = initialBubbles.keys.filter { $0.row > 1 && !excluded.contains($0) }.sorted { $0.row == $1.row ? $0.column < $1.column : $0.row < $1.row }
        return Set(candidates.prefix(index < 100 ? 1 : 2))
    }
}

struct LevelPlayResults: Codable, Equatable {
    static let balanceVersion = 4
    var version = LevelPlayResults.balanceVersion
    var wins = 0
    // Optional so existing on-device statistics decode without losing history.
    var recentLosses: Int? = nil
    var consecutiveLosses: Int { max(0, recentLosses ?? 0) }
    var losses = 0
    var shotsUsed = 0
    var shotsSavedOnWins = 0
    var bankMatches = 0
    var boosterShots = 0
    var completedRuns: Int { wins + losses }
    var winRate: Int { completedRuns == 0 ? 0 : wins * 100 / completedRuns }
    var averageSaved: Int { wins == 0 ? 0 : shotsSavedOnWins / wins }
    mutating func record(won: Bool, fired: Int, remaining: Int, banks: Int, boosters: Int) {
        if version != Self.balanceVersion { self = LevelPlayResults() }
        recentLosses = won ? 0 : consecutiveLosses + 1
        if won { wins += 1; shotsSavedOnWins += max(0, remaining) } else { losses += 1 }
        shotsUsed += max(0, fired); bankMatches += max(0, banks); boosterShots += max(0, boosters)
    }
}

enum PuzzleRewards {
    static func bankBonus(bounces: Int, removed: Int) -> Int {
        bounces > 0 && removed > 0 ? 50 : 0
    }
}
