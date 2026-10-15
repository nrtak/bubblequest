import AVFoundation

final class FestivalAudio {
    private var music: AVAudioPlayer?
    private var effects: [AVAudioPlayer] = []
    private var track = ""
    private var suspended = false
    private var fadingTracks: [AVAudioPlayer] = []

    static func track(menu: String, area: Int, challenge: Bool) -> String {
        if ["title", "players", "saved-progress"].contains(menu) { return "music-menu" }
        if ["host", "neighbor-detail", "buddy-welcome", "ending"].contains(menu) { return "music-story" }
        if ["map", "album", "neighbors", "map-buddies", "quests", "quest-detail", "wheel", "wheel-reward"].contains(menu) { return "music-map" }
        if challenge { return "music-challenge" }
        if let scenery = SummerScenery.forArea(area) {
            return [.river, .beach, .lake].contains(scenery) ? "music-water" : "music-countryside"
        }
        return area < 2 ? "music-day" : "music-evening"
    }

    func update(name: String, enabled: Bool, volume: Float = 0.22) {
        if track != name {
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
                  let replacement = try? AVAudioPlayer(contentsOf: url) else { return }
            track = name
            if let old = music {
                old.setVolume(0, fadeDuration: 0.8)
                fadingTracks.append(old)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self, weak old] in
                    old?.stop()
                    self?.fadingTracks.removeAll { $0 === old }
                }
            }
            music = replacement
            music?.numberOfLoops = -1
            music?.volume = 0
            music?.prepareToPlay()
        }
        if enabled && !suspended {
            music?.play()
            music?.setVolume(volume, fadeDuration: 0.8)
        } else {
            music?.pause()
            fadingTracks.forEach { $0.stop() }
        }
    }

    func effect(_ name: String, enabled: Bool, volume: Float = 0.6) {
        guard enabled, !suspended,
              let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        effects.removeAll { !$0.isPlaying }
        if effects.count >= 4 { effects.removeFirst().stop() }
        player.volume = volume
        effects.append(player)
        player.play()
    }

    func suspend(_ value: Bool) {
        suspended = value
        if value { music?.pause(); fadingTracks.forEach { $0.stop() }; effects.forEach { $0.stop() } }
    }
}
