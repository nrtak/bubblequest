import Foundation

struct FestivalHost {
    let id: String
    let name: String
    let role: String
    let area: Int
    let portraitIndex: Int
    let introduction: [String]
    let encouragement: String

    static let all: [FestivalHost] = [
        FestivalHost(id: "hana", name: "Hana", role: "Market stallkeeper", area: 0, portraitIndex: 0,
                     introduction: ["Hi, I'm Hana! Welcome to Sunlit Market.",
                                    "Pick a stop and let's get those bubbles popping!"],
                     encouragement: "Lovely popping! The market is cheering you on."),
        FestivalHost(id: "ren", name: "Ren", role: "Courtyard organizer", area: 1, portraitIndex: 1,
                     introduction: ["I'm Ren! I help keep this courtyard full of fun.",
                                    "You've earned a new place to play. Ready for the next round?"],
                     encouragement: "That deserves a festival cheer!"),
        FestivalHost(id: "aki", name: "Aki", role: "Lantern maker", area: 2, portraitIndex: 2,
                     introduction: ["Welcome to Lantern Street. I'm Aki.",
                                    "I made these lanterns for tonight. Take your time and enjoy the glow."],
                     encouragement: "A thoughtful shot can brighten the whole board."),
        FestivalHost(id: "sora", name: "Sora", role: "Riverside food vendor", area: 3, portraitIndex: 3,
                     introduction: ["Hello there! I'm Sora, from the riverside food stall.",
                                    "The breeze is lovely here. Let's enjoy a few more puzzles together."],
                     encouragement: "Nice work! There's always another good stop ahead."),
        FestivalHost(id: "yui", name: "Yui", role: "Fireworks coordinator", area: 4, portraitIndex: 4,
                     introduction: ["I'm Yui! You've made it to Firework Night.",
                                    "Let's finish the festival with some spectacular pops!"],
                     encouragement: "What a finish! You lit up the festival.")
    ]
}

extension GameProgress {
    func hostIsAvailable(_ host: FestivalHost) -> Bool {
        unlockedLevel >= host.area * LevelCatalog.levelsPerArea
    }
}
