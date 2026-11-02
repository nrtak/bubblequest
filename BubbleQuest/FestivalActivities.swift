import Foundation

struct DailyFestivalPuzzle: Codable, Equatable {
    let day: String
    let level: Int
    let seed: UInt64

    static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    static func make(now: Date, unlocked: Int) -> DailyFestivalPuzzle {
        let day = dayKey(now)
        let seed = day.utf8.reduce(UInt64(14695981039346656037)) { ($0 ^ UInt64($1)) &* 1099511628211 }
        // Stay within the player's familiar mechanics; freeze the selection for the day.
        let upper = min(LevelCatalog.levelCount - 1, max(0, unlocked))
        let lower = max(0, upper - 19)
        return DailyFestivalPuzzle(day: day, level: lower + Int(seed % UInt64(upper - lower + 1)), seed: seed)
    }
    var definition: GameLevel { LevelCatalog.level(level).randomized(seed: seed) }
    var difficulty: String { definition.difficultyTitle }
}

enum GardenDecoration: String, Codable, CaseIterable {
    case blossoms, bunting, pinwheel, lantern, picnic, fireworks, luckyStar
    var title: String {
        switch self {
        case .blossoms: return "Blossoms"
        case .bunting: return "Market bunting"
        case .pinwheel: return "Pinwheel"
        case .lantern: return "Paper lantern"
        case .picnic: return "Picnic basket"
        case .fireworks: return "Festival lights"
        case .luckyStar: return "Lucky star"
        }
    }
    var symbol: String {
        switch self {
        case .blossoms: return "camera.macro"
        case .bunting: return "flag.fill"
        case .pinwheel: return "sun.max.fill"
        case .lantern: return "lightbulb.fill"
        case .picnic: return "basket.fill"
        case .fireworks: return "sparkles"
        case .luckyStar: return "star.fill"
        }
    }
    var questID: String? {
        switch self {
        case .blossoms: return nil
        case .bunting: return "parcels"
        case .pinwheel: return "pinwheels"
        case .lantern: return "lanterns"
        case .picnic: return "picnic"
        case .fireworks: return "sparks"
        case .luckyStar: return "toy"
        }
    }
}

/// Separate from campaign progress: a daily attempt never replaces a saved level.
final class FestivalActivities {
    private struct State: Codable {
        var daily: DailyFestivalPuzzle?
        var checkpoint: GameCheckpoint?
        var rewardedDays: Set<String> = []
        var placements: [Int: GardenDecoration] = [:]
    }
    private let defaults: UserDefaults
    private var state: State
    init(defaults: UserDefaults) {
        self.defaults = defaults
        state = defaults.data(forKey: "festivalActivities").flatMap { try? JSONDecoder().decode(State.self, from: $0) } ?? State()
    }
    private func save() {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: "festivalActivities"); defaults.set(Date(), forKey: "lastSaved") }
    }
    func daily(now: Date = Date(), unlocked: Int) -> DailyFestivalPuzzle {
        let day = DailyFestivalPuzzle.dayKey(now)
        if let daily = state.daily, daily.day == day, LevelCatalog.levels.indices.contains(daily.level) { return daily }
        let daily = DailyFestivalPuzzle.make(now: now, unlocked: unlocked)
        state.daily = daily; state.checkpoint = nil; save()
        return daily
    }
    func checkpoint(for puzzle: DailyFestivalPuzzle) -> GameCheckpoint? {
        guard state.daily == puzzle, let checkpoint = state.checkpoint,
              checkpoint.level == puzzle.level, checkpoint.layoutSeed == puzzle.seed,
              checkpoint.challenge == true, checkpoint.board != nil else { return nil }
        return checkpoint
    }
    func save(_ checkpoint: GameCheckpoint, for puzzle: DailyFestivalPuzzle) {
        guard state.daily == puzzle, checkpoint.level == puzzle.level,
              checkpoint.layoutSeed == puzzle.seed, checkpoint.challenge == true, checkpoint.board != nil else { return }
        state.checkpoint = checkpoint; save()
    }
    func clearCheckpoint(for puzzle: DailyFestivalPuzzle) {
        guard state.daily == puzzle else { return }
        state.checkpoint = nil; save()
    }
    func completed(_ puzzle: DailyFestivalPuzzle) -> Bool { state.rewardedDays.contains(puzzle.day) }
    @discardableResult
    func complete(_ puzzle: DailyFestivalPuzzle, adventure: AdventureProgress) -> Bool {
        guard state.daily == puzzle, !completed(puzzle) else { return false }
        adventure.awardDailyRainbow(day: puzzle.day)
        state.rewardedDays.insert(puzzle.day); state.checkpoint = nil
        save()
        return true
    }
    func availableDecorations(adventure: AdventureProgress) -> [GardenDecoration] {
        GardenDecoration.allCases.filter { decoration in
            if decoration == .bunting && adventure.hasBunting { return true }
            guard let id = decoration.questID else { return true }
            return FestivalQuest.all.first { $0.id == id }.map { adventure.completed($0) } ?? false
        }
    }
    func decoration(at slot: Int) -> GardenDecoration? { state.placements[slot] }
    func place(_ decoration: GardenDecoration?, at slot: Int, adventure: AdventureProgress) {
        guard (0..<6).contains(slot), decoration == nil || availableDecorations(adventure: adventure).contains(decoration!) else { return }
        state.placements[slot] = decoration; save()
    }
}

extension GameLevel {
    var difficultyTitle: String {
        if isMilestone { return "Festival finale" }
        if number.isMultiple(of: 10) { return "Milestone challenge" }
        if index < 5 { return "Getting started" }
        if isBankRoute || isPrecision { return "Tricky" }
        return index < 20 ? "Gentle" : index < 60 ? "Tricky" : "Challenging"
    }
}


enum FestivalMoments {
    static func message(area: Int, stop: Int) -> String {
        switch stop {
        case 5: return ["The stalls are buzzing thanks to you!", "Our pinwheels are dancing!", "Look at those lanterns glow!", "The picnic crowd is cheering!", "That's a sparkling start!"][max(0, area) % 5]
        case 10: return ["Halfway there! Let's bring the whole market to life.", "A clever finish! The courtyard is cheering.", "Ten bright stops! The lantern makers send their thanks.", "What a splash! Our river friends are celebrating.", "Ten stops lit up! Ready for the next surprise?"][max(0, area) % 5]
        default: return "A whole neighborhood of wonderful popping! See you on the festival path."
        }
    }
}
