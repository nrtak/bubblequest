import Foundation

struct FestivalNeighbor {
    let id: String
    let name: String
    let role: String
    let area: Int
    let portraitIndex: Int
    let introduction: String
    let greeting: String

    static let all: [FestivalNeighbor] = [
        FestivalNeighbor(id: "miki", name: "Miki", role: "Tea stall neighbor", area: 0, portraitIndex: 0,
                         introduction: "I'm Miki. I brought tea from the countryside for our little market. Follow the path whenever you're ready!",
                         greeting: "The kettle is warm and the market is bustling. It's lovely to see you again."),
        FestivalNeighbor(id: "toma", name: "Toma", role: "Toy boat maker", area: 0, portraitIndex: 1,
                         introduction: "Hi, I'm Toma! I make tiny boats that sail across the summer pond. They look lovely drifting past the stalls.",
                         greeting: "I've been testing a new little boat. Perhaps we'll sail it together after your next puzzle."),
        FestivalNeighbor(id: "chiyo", name: "Chiyo", role: "Courtyard gardener", area: 1, portraitIndex: 2,
                         introduction: "I'm Chiyo. I've cared for this courtyard for years. Ren's pinwheels look wonderful among the flowers, don't they?",
                         greeting: "A cool patch of shade and a colorful pinwheel always brighten a summer afternoon."),
        FestivalNeighbor(id: "rika", name: "Rika", role: "Countryside tea grower", area: 2, portraitIndex: 3,
                         introduction: "Hello, I'm Rika! I came from the tea fields to see Aki's lanterns. The hills are glowing in the evening sun.",
                         greeting: "I brought a fresh basket of tea leaves. Let's enjoy the lantern glow a little longer."),
        FestivalNeighbor(id: "jun", name: "Jun", role: "Riverside picnic neighbor", area: 3, portraitIndex: 4,
                         introduction: "I'm Jun. Sora asked me to find a picnic spot by the water. There's room for all our friends here!",
                         greeting: "The river breeze is lovely today. I've kept a comfortable spot for you and your buddies."),
        FestivalNeighbor(id: "koji", name: "Koji", role: "Festival drummer", area: 4, portraitIndex: 5,
                         introduction: "Welcome! I'm Koji. I keep a gentle festival rhythm while Yui prepares the fireworks. You've traveled a long way!",
                         greeting: "The lanterns are lit and our neighbors have gathered. Let's give the festival a cheerful finale."),
        FestivalNeighbor(id: "aya", name: "Aya", role: "Summer flower seller", area: 1, portraitIndex: 6,
                         introduction: "Hi, I'm Aya! I brought summer flowers for the courtyard. There are so many colors to choose from!",
                         greeting: "I've put together another little bouquet. The warm sunshine has brought out all the blossoms."),
        FestivalNeighbor(id: "shin", name: "Shin", role: "Lantern street helper", area: 2, portraitIndex: 7,
                         introduction: "I'm Shin. I help our neighbors hang their ribbons and lanterns. Aki always finds the nicest colors for this street.",
                         greeting: "Another ribbon is in place! It's lovely seeing everyone make this street their own."),
        FestivalNeighbor(id: "gin", name: "Gin", role: "Gear workshop helper", area: 5, portraitIndex: 8,
                         introduction: "I help keep our festival machines running. Welcome to the summer river!",
                         greeting: "The gears are turning smoothly. Ready for another puzzle?"),
        FestivalNeighbor(id: "rui", name: "Rui", role: "Tea terrace neighbor", area: 6, portraitIndex: 9,
                         introduction: "I brought fresh tea from these sunny hills. Take your time and enjoy the view.",
                         greeting: "The tea is ready, and the countryside is glowing today."),
        FestivalNeighbor(id: "souta", name: "Souta", role: "Seaside kite maker", area: 7, portraitIndex: 10,
                         introduction: "The sea breeze is perfect for flying kites. Welcome to our beach festival!",
                         greeting: "My kite is flying high above the bay. Good luck with your next puzzle!"),
        FestivalNeighbor(id: "midori", name: "Midori", role: "Windmill garden neighbor", area: 8, portraitIndex: 11,
                         introduction: "I put colorful windmills beside the lake. They spin whenever a little breeze comes by.",
                         greeting: "The windmills are turning, and the lake looks lovely."),
        FestivalNeighbor(id: "akane", name: "Akane", role: "Hilltop lantern helper", area: 9, portraitIndex: 12,
                         introduction: "I brought a few lanterns for our hilltop picnic. There is a wonderful view from up here!",
                         greeting: "The flowers are bright and the picnic spot is ready."),
        FestivalNeighbor(id: "rin", name: "Rin", role: "Summer fan maker", area: 10, portraitIndex: 13,
                         introduction: "I make little flower fans to keep everyone cool. It is nice to meet you by the river!",
                         greeting: "I found another flower pattern for my fans. Welcome back!")
    ]
}

