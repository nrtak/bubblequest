import Foundation
import CoreGraphics

/// Projects use distinct campaign clears, never attempts, replay wins, or daily puzzles.
struct FestivalProject {
    enum DisplayStyle: Equatable { case stall, pinwheels, lanternWalk, picnic, fireworks, kites }
    let area: Int
    let title: String
    let symbol: String
    let finale: String
    let invitation: String
    static let thresholds = [5, 10, 15, 20]
    static let stageNames = ["Set the stage", "Add decorations", "Light it up", "Opening day"]
    var levels: Range<Int> {
        let first = area * LevelCatalog.levelsPerArea
        return first..<(first + LevelCatalog.levelsPerArea)
    }
    var finaleLevel: Int { levels.upperBound - 1 }
    /// Each neighborhood keeps its own resident and setting in story scenes.
    var illustrationName: String {
        switch area {
        case 0: return "festival-story-market-v2"
        case 1: return "festival-story-parade-v2"
        case 2: return "festival-story-lantern-v2"
        case 3: return "festival-story-picnic-v2"
        case 4: return "festival-story-fireworks-v2"
        case 5: return "festival-story-river-v2"
        case 6: return "festival-story-tea-v2"
        case 7: return "festival-story-kites-v2"
        case 8: return "festival-story-lake-v2"
        case 9: return "festival-story-hilltop-v2"
        default: return "festival-story-fan-fair-v2"
        }
    }
    var displayStyle: DisplayStyle {
        switch area {
        case 1: return .pinwheels
        case 2, 8: return .lanternWalk
        case 3, 6: return .picnic
        case 4, 10: return .fireworks
        case 7: return .kites
        default: return .stall
        }
    }
    func story(stage: Int) -> String {
        guard stage > 0 else { return invitation }
        if area == 9 {
            let lookout = ["Our lookout is ready for its first flags.", "The flags add color high above the town.",
                           "The lanterns are glowing. Our neighbors are nearly here!", "What a view! Our hilltop gathering is ready for everyone."]
            return lookout[min(3, stage - 1)]
        }
        let lines: [String]
        switch displayStyle {
        case .stall:
            lines = ["Our stall is standing! Let's add some color.", "The decorations are up. Let's light the lanterns.", "The lights are on! Our first visitors are nearly here.", "We're open! Look at everyone you've brought together."]
        case .pinwheels:
            lines = ["Our first pinwheels are spinning!", "The parade route is full of color.", "Our neighbors are gathering. The parade is almost ready!", "Here comes our parade! You gave it a wonderful start."]
        case .lanternWalk:
            lines = ["The arch is ready for its first lanterns.", "The lanterns are hung. Let's bring them to life.", "Look at that glow! One last stretch to light.", "The whole walkway is glowing. Our friends can follow it home."]
        case .picnic:
            lines = ["We've found a lovely gathering spot.", "The cloth and baskets are ready.", "Our friends are on their way. Let's finish preparing!", "There's a place for everyone. We saved you a seat!"]
        case .fireworks:
            lines = ["Our festival stage is standing!", "The colors are ready for rehearsal.", "Just a few more preparations before the big show.", "What a show! Everyone helped make this moment happen."]
        case .kites:
            lines = ["Our first kite is ready for the sea breeze.", "The ribbons are dancing above the coast.", "The parade is nearly ready to take flight!", "Look up! Our kites are flying for the whole neighborhood."]
        }
        return lines[min(3, stage - 1)]
    }
    static let all: [FestivalProject] = [
        FestivalProject(area: 0, title: "Hana's festival stall", symbol: "basket.fill", finale: "Market opening!", invitation: "Let's turn this quiet corner into a welcoming festival stall."),
        FestivalProject(area: 1, title: "The pinwheel pavilion", symbol: "sun.max.fill", finale: "The pinwheel parade!", invitation: "Help fill the courtyard with spinning pinwheels and happy neighbors."),
        FestivalProject(area: 2, title: "The lantern walk", symbol: "lightbulb.fill", finale: "Lantern lighting!", invitation: "Let's make a glowing lantern walk for everyone to enjoy."),
        FestivalProject(area: 3, title: "The riverside picnic", symbol: "basket.fill", finale: "Picnic by the river!", invitation: "Help prepare a riverside gathering for our festival friends."),
        FestivalProject(area: 4, title: "The fireworks stage", symbol: "sparkles", finale: "Opening night!", invitation: "Build a sparkling stage for a night of festival surprises."),
        FestivalProject(area: 5, title: "The river welcome", symbol: "drop.fill", finale: "The river celebration!", invitation: "Let's prepare a cheerful welcome along the river."),
        FestivalProject(area: 6, title: "The tea garden", symbol: "leaf.fill", finale: "Tea garden opening!", invitation: "Help create a cozy gathering place beside the tea fields."),
        FestivalProject(area: 7, title: "Shota's kite parade", symbol: "wind", finale: "Kites over the coast!", invitation: "Let's fill the sea breeze with colorful kites and ribbons."),
        FestivalProject(area: 8, title: "The lakeside lights", symbol: "lightbulb.fill", finale: "Lights on the lake!", invitation: "Help light a lakeside meeting place for our friends."),
        FestivalProject(area: 9, title: "The hilltop festival", symbol: "flag.fill", finale: "The hilltop gathering!", invitation: "Let's turn the hilltop into a colorful festival lookout."),
        FestivalProject(area: 10, title: "The grand fan fair", symbol: "fan.fill", finale: "The grand festival!", invitation: "Bring everyone together for one last joyful festival gathering.")
    ]
    static func forArea(_ area: Int) -> FestivalProject? { all.first { $0.area == area } }

    /// Four small roadside installations mark the preparation milestones.
    func sitePosition(stage: Int) -> CGPoint {
        let level = levels.lowerBound + Self.thresholds[min(3, max(0, stage))] - 1
        let marker = FestivalMapLayout.position(level)
        return CGPoint(x: marker.x >= 195 ? 72 : 318, y: marker.y - 20)
    }
}

struct FestivalProjectStatus {
    let project: FestivalProject
    let cleared: Int
    let medals: Int
    let rewardCollected: Bool
    var stage: Int { FestivalProject.thresholds.filter { cleared >= $0 }.count }
    var complete: Bool { cleared == project.levels.count }
    var nextThreshold: Int { FestivalProject.thresholds.first { $0 > cleared } ?? project.levels.count }
    var nextReward: String {
        if complete { return rewardCollected ? "Festival ready! Tap to visit." : "Festival ready! Collect Rainbow + Bomb." }
        let left = nextThreshold - cleared
        let milestone = FestivalProject.stageNames[min(3, stage)].lowercased()
        return "\(left) more \(left == 1 ? "level" : "levels") " + (stage == 3 ? "until " : "to ") + milestone
    }
}

extension GameProgress {
    func festivalProject(area: Int) -> FestivalProjectStatus? {
        guard let project = FestivalProject.forArea(area) else { return nil }
        // Decode the collection once per project, not once for each of its 20 levels.
        let storedMedals = collection.medals
        let earnedMedals = project.levels.reduce(0) { total, level in
            var medals = storedMedals[level] ?? []
            if stars(level) == PuzzleRating.maximumStars { medals.insert(.fiveStars) }
            return total + medals.count
        }
        return FestivalProjectStatus(project: project,
                                     cleared: project.levels.filter { stars($0) > 0 }.count,
                                     medals: earnedMedals,
                                     rewardCollected: adventure.hasProjectReward(area))
    }
    @discardableResult
    func claimProjectReward(area: Int) -> Bool {
        guard let status = festivalProject(area: area), status.complete else { return false }
        return adventure.awardProjectReward(area: area)
    }
}
