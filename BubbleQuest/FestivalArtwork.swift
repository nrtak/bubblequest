import Foundation

/// Quiet paintings keep the playfield clear while preserving each neighborhood's identity.
enum FestivalArtwork {
    static let gameplayNames: [String: String] = [
        "festival-day": "festival-gameplay-market-calm-v1.jpg",
        "festival-courtyard": "festival-gameplay-courtyard-calm-v1.jpg",
        "festival-lantern": "festival-gameplay-lantern-calm-v1.jpg",
        "festival-riverside": "festival-gameplay-riverside-calm-v1.jpg",
        "festival-dusk": "festival-gameplay-dusk-calm-v1.jpg",
        "festival-tea-fields": "festival-gameplay-tea-calm-v1.jpg",
        "festival-beach": "festival-gameplay-beach-calm-v1.jpg",
        "festival-summer-water": "festival-gameplay-lake-calm-v1.jpg",
        "festival-coastal-hill": "festival-gameplay-hill-calm-v1.jpg"
    ]

    static let mapNames = [
        "festival-map-market-calm-v1.jpg",
        "festival-map-parade-calm-v1.jpg",
        "festival-map-lantern-calm-v1.jpg",
        "festival-map-picnic-calm-v1.jpg",
        "festival-map-fireworks-calm-v1.jpg",
        "festival-map-river-calm-v1.jpg",
        "festival-map-tea-calm-v1.jpg",
        "festival-map-kites-calm-v1.jpg",
        "festival-map-lake-calm-v1.jpg",
        "festival-map-hilltop-calm-v1.jpg",
        "festival-map-fan-fair-calm-v1.jpg"
    ]

    static func gameplayName(for background: String) -> String? { gameplayNames[background] }

    /// Overlapping windows from a single painted world; their shared pixels match.
    static let journeyNames = (0..<39).map { String(format: "festival-world-v2-%02d.jpg", $0) }

    static func journeyName(for segment: Int) -> String? {
        guard journeyNames.indices.contains(segment) else { return nil }
        return journeyNames[segment]
    }

    static func mapName(for area: Int) -> String? {
        guard mapNames.indices.contains(area) else { return nil }
        return mapNames[area]
    }
}
