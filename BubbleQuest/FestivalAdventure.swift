import Foundation

struct FestivalQuest {
    enum Goal { case clear, bounce, drop, color(Int) }
    let id: String
    let title: String
    let area: Int
    let symbol: String
    let invitation: String
    let steps: [String]
    let goals: [Goal]
    let thanks: String
    func conversation(step: Int) -> String {
        guard step > 0 else { return invitation }
        switch id {
        case "lanterns": return step == 1 ? "The blossom charm is back! Let's look for the river charm next." : "Only the star charm is missing now. Then we can light the whole display!"
        case "parcels": return step == 1 ? "I've tied that tag to its parcel. Let's check by the next stall." : "Just one parcel left. Its owner will be so pleased!"
        case "pinwheels": return step == 1 ? "That clever bounce gave us our first pinwheel. Let's send a group tumbling!" : "The garden is coming together. One more clever bounce will finish it."
        case "picnic": return step == 1 ? "The cloth is ready by the river. Can you help bring down our basket?" : "Our basket is packed. Let's gather the last surprise for our friends."
        case "sparks": return step == 1 ? "Those blue sparks are lovely. Let's add a little coral glow." : "A touch of gold will make our rehearsal shine!"
        default: return step == 1 ? "Those little paw prints lead past Hana's stall. Shiba is getting excited!" : "A scrap of ribbon! Shiba thinks the toy must be very close."
        }
    }
    func artifact(step: Int) -> String {
        if id == "lanterns" { return ["leaf.fill", "drop.fill", "star.fill"][min(2, step)] }
        if id == "picnic" { return ["square.grid.3x3.fill", "basket.fill", "heart.fill"][min(2, step)] }
        if id == "toy" && step == 2 { return "tennisball.fill" }
        return symbol
    }

    static let all: [FestivalQuest] = [
        FestivalQuest(id: "parcels", title: "Hana's delivery", area: 0, symbol: "tag.fill",
                      invitation: "Some parcel tags blew into the market! Will you help me gather them?",
                      steps: ["Find the first parcel tag", "Find the next parcel tag", "Bring home the final tag"],
                      goals: [.clear, .clear, .clear], thanks: "Every parcel has a home again! Your stall bunting is ready."),
        FestivalQuest(id: "pinwheels", title: "Ren's pinwheel garden", area: 1, symbol: "sun.max.fill",
                      invitation: "Let's bring some color back to the courtyard's pinwheel garden.",
                      steps: ["Win with a wall bounce", "Win with a bubble drop", "Win another wall-bounce puzzle"],
                      goals: [.bounce, .drop, .bounce], thanks: "Look at our garden spin! Choose its new colors."),
        FestivalQuest(id: "lanterns", title: "Aki's lantern display", area: 2, symbol: "lightbulb.fill",
                      invitation: "Three paper charms are missing from my display. Let's find them together.",
                      steps: ["Recover the blossom charm", "Recover the river charm", "Recover the star charm"],
                      goals: [.clear, .clear, .clear], thanks: "My display is glowing again. Choose your favorite lantern color!"),
        FestivalQuest(id: "picnic", title: "Sora's riverside picnic", area: 3, symbol: "basket.fill",
                      invitation: "A picnic is even better with friends. Can you help gather our supplies?",
                      steps: ["Find the picnic cloth", "Gather the picnic basket", "Bring the buddies together"],
                      goals: [.clear, .drop, .clear], thanks: "The picnic is ready! Everyone saved you a lovely spot by the river."),
        FestivalQuest(id: "sparks", title: "Yui's fireworks rehearsal", area: 4, symbol: "sparkles",
                      invitation: "Let's gather three colors for a little fireworks rehearsal.",
                      steps: ["Win after clearing blue sparks", "Win after clearing coral sparks", "Win after clearing golden sparks"],
                      goals: [.color(2), .color(0), .color(1)], thanks: "What beautiful colors! Pick the glow for our finale."),
        FestivalQuest(id: "toy", title: "Shiba's lost toy", area: 0, symbol: "pawprint.fill",
                      invitation: "Shiba left a favorite toy somewhere along the market path. Follow the little clues!",
                      steps: ["Find the first paw-print clue", "Follow the next paw-print clue", "Find Shiba's favorite toy"],
                      goals: [.clear, .clear, .clear], thanks: "You found it! Shiba has a new lucky star pin and a big thank-you." )
    ]
}

struct QuestPlay: Codable {
    var bounces = 0
    var dropped = 0
    var colors: Set<Int> = []
    var collected: Set<String> = []
}

enum FestivalPrize: String, Codable, CaseIterable {
    case rainbow, bomb, blossomPin, starPin, riverPin, lanternColors
    var title: String {
        switch self {
        case .rainbow: return "Extra Rainbow"
        case .bomb: return "Extra Bomb"
        case .blossomPin: return "Blossom Pin"
        case .starPin: return "Star Pin"
        case .riverPin: return "River Pin"
        case .lanternColors: return "Festival Bunting"
        }
    }
    var symbol: String {
        switch self {
        case .rainbow: return "rainbow"
        case .bomb: return "burst.fill"
        case .blossomPin: return "leaf.fill"
        case .starPin: return "star.fill"
        case .riverPin: return "drop.fill"
        case .lanternColors: return "flag.fill"
        }
    }
}

final class AdventureProgress {
    private struct State: Codable {
        var accepted: Set<String> = []
        var wins: [String: [Int]] = [:]
        var styles: [String: Int] = [:]
        var completedLevels = 0
        var spentSpins = 0
        var pins: Set<FestivalPrize> = []
        var equippedPin: FestivalPrize?
        var rainbowGifts = 0
        var bombGifts = 0
        var lastPrize: FestivalPrize?
    }
    private let defaults: UserDefaults
    private var state: State
    init(defaults: UserDefaults) {
        self.defaults = defaults
        state = defaults.data(forKey: "festivalAdventure").flatMap { try? JSONDecoder().decode(State.self, from: $0) } ?? State()
    }
    private func save() { if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: "festivalAdventure") } }
    func accepted(_ quest: FestivalQuest) -> Bool { state.accepted.contains(quest.id) }
    func count(_ quest: FestivalQuest) -> Int { min(quest.steps.count, state.wins[quest.id]?.count ?? 0) }
    func completed(_ quest: FestivalQuest) -> Bool { count(quest) == quest.steps.count }
    func accept(_ quest: FestivalQuest, unlockedLevel: Int) {
        guard unlockedLevel >= quest.area * 10 else { return }
        state.accepted.insert(quest.id); save()
    }
    func synchronize(completedLevels: Int) { state.completedLevels = max(state.completedLevels, completedLevels); save() }
    var availableSpins: Int { max(0, state.completedLevels / 5 + FestivalQuest.all.filter(completed).count - state.spentSpins) }
    var rainbowGifts: Int { state.rainbowGifts }
    var bombGifts: Int { state.bombGifts }
    var equippedPin: FestivalPrize? { state.equippedPin }
    var lastPrize: FestivalPrize? { state.lastPrize }
    func nextLevel(_ quest: FestivalQuest, unlockedLevel: Int) -> Int? {
        (quest.area * 10..<quest.area * 10 + 10).first {
            $0 <= unlockedLevel && !(state.wins[quest.id] ?? []).contains($0)
        }
    }
    func consumeGift(_ shot: BubbleShot) {
        if shot == .rainbow { state.rainbowGifts = max(0, state.rainbowGifts - 1) }
        if shot == .bomb { state.bombGifts = max(0, state.bombGifts - 1) }
        save()
    }
    func style(_ quest: FestivalQuest) -> Int { state.styles[quest.id] ?? 0 }
    func chooseStyle(_ value: Int, for quest: FestivalQuest) {
        guard completed(quest), (0..<3).contains(value) else { return }
        state.styles[quest.id] = value; save()
    }
    func equip(_ pin: FestivalPrize?) {
        guard pin == nil || state.pins.contains(pin!) else { return }
        state.equippedPin = pin; save()
    }
    var unlockedPins: [FestivalPrize] { FestivalPrize.allCases.filter { state.pins.contains($0) && $0 != .lanternColors } }
    @discardableResult
    func recordWin(level: Int, play: QuestPlay, completedLevels: Int) -> [FestivalQuest] {
        guard LevelCatalog.levels.indices.contains(level) else { return [] }
        state.completedLevels = max(state.completedLevels, completedLevels)
        var newlyFinished: [FestivalQuest] = []
        for quest in FestivalQuest.all where accepted(quest) && !completed(quest) && quest.area == level / 10 {
            let previous = state.wins[quest.id] ?? []
            guard !previous.contains(level) else { continue }
            let goal = quest.goals[previous.count]
            let qualifies: Bool
            switch goal {
            case .clear: qualifies = play.collected.contains(quest.id)
            case .bounce: qualifies = play.bounces > 0
            case .drop: qualifies = play.dropped > 0
            case .color(let color): qualifies = play.colors.contains(color)
            }
            guard qualifies else { continue }
            state.wins[quest.id] = previous + [level]
            if completed(quest) { newlyFinished.append(quest) }
        }
        if newlyFinished.contains(where: { $0.id == "toy" }) { state.pins.insert(.starPin); state.equippedPin = .starPin }
        save(); return newlyFinished
    }
    func draw<R: RandomNumberGenerator>(using random: inout R) -> FestivalPrize? {
        guard availableSpins > 0 else { return nil }
        // Eight equally likely booster tickets and two cosmetic tickets per ten draws.
        let ticket = Int.random(in: 0..<10, using: &random)
        var prize: FestivalPrize = ticket < 4 ? .rainbow : ticket < 8 ? .bomb
            : [FestivalPrize.blossomPin, .starPin, .riverPin, .lanternColors].randomElement(using: &random)!
        if state.pins.contains(prize) { prize = Bool.random(using: &random) ? .rainbow : .bomb }
        state.spentSpins += 1
        state.lastPrize = prize
        switch prize {
        case .rainbow: state.rainbowGifts += 1
        case .bomb: state.bombGifts += 1
        default: state.pins.insert(prize); if prize != .lanternColors { state.equippedPin = prize }
        }
        save(); return prize
    }
    var hasBunting: Bool { state.pins.contains(.lanternColors) }
}
