import AVFoundation

protocol FestivalMusicPlaying: AnyObject {
    var numberOfLoops: Int { get set }
    var volume: Float { get set }
    var isPlaying: Bool { get }
    @discardableResult func play() -> Bool
    @discardableResult func prepareToPlay() -> Bool
    func pause()
    func stop()
    func setVolume(_ volume: Float, fadeDuration: TimeInterval)
}

extension AVAudioPlayer: FestivalMusicPlaying {}

final class FestivalAudio {
    private var music: FestivalMusicPlaying?
    private var effects: [AVAudioPlayer] = []
    private var track = ""
    private var suspended = false
    private var entranceDuration: TimeInterval = 0.8
    private var fadingTracks: [FestivalMusicPlaying] = []
    private let makeMusic: (String) -> FestivalMusicPlaying?
    private var lastEffects: [String: TimeInterval] = [:]

    init(makeMusic: @escaping (String) -> FestivalMusicPlaying? = { name in
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        return try? AVAudioPlayer(contentsOf: url)
    }) {
        self.makeMusic = makeMusic
    }

    static func track(menu: String, area: Int, challenge: Bool) -> String {
        if ["title", "players", "saved-progress"].contains(menu) { return "music-menu" }
        if ["host", "neighbor-detail", "buddy-welcome", "courtyard-welcome", "ending", "festival-project"].contains(menu) { return "music-story" }
        if ["map", "map-extras", "level-briefing", "album", "neighbors", "map-buddies", "companion-preview", "quests", "quest-detail", "wheel", "wheel-reward", "daily-puzzle", "festival-garden"].contains(menu) { return "music-map" }
        if challenge { return "music-challenge" }
        if let scenery = SummerScenery.forArea(area) {
            return [.river, .beach, .lake].contains(scenery) ? "music-water" : "music-countryside"
        }
        return area < 2 ? "music-day" : "music-evening"
    }

    func update(name: String, enabled: Bool, volume: Float = 0.22) {
        let gain = volume.isFinite ? min(1, max(0, volume)) : 0
        let shouldPlay = enabled && !suspended && gain > 0
        // Honor mute even if the requested replacement resource cannot be loaded.
        if !shouldPlay { music?.pause(); stopFades() }
        if track != name {
            guard let replacement = makeMusic(name) else { return }
            entranceDuration = track.isEmpty ? 1.2 : 0.8
            track = name
            if let old = music {
                if !shouldPlay || !old.isPlaying { old.stop() }
                else {
                    old.setVolume(0, fadeDuration: 0.8)
                    fadingTracks.append(old)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self, weak old] in
                        old?.stop()
                        self?.fadingTracks.removeAll { $0 === old }
                    }
                }
            }
            music = replacement
            music?.numberOfLoops = -1
            music?.volume = 0
            music?.prepareToPlay()
        }
        if shouldPlay {
            music?.play()
            music?.setVolume(gain, fadeDuration: entranceDuration)
        } else {
            music?.pause()
            stopFades()
        }
    }

    func effect(_ name: String, enabled: Bool, volume: Float = 0.6) {
        let now = ProcessInfo.processInfo.systemUptime
        guard enabled, !suspended, volume.isFinite, volume > 0,
              now - (lastEffects[name] ?? -10) >= 0.06,
              let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        effects.removeAll { !$0.isPlaying }
        if effects.count >= 4 { effects.removeFirst().stop() }
        lastEffects[name] = now
        player.volume = FestivalSoundMix.effectVolume(name: name, requested: volume)
        effects.append(player)
        player.play()
    }

    func stopEffects() {
        effects.forEach { $0.stop() }
        effects.removeAll()
        lastEffects.removeAll()
    }

    private func stopFades() {
        fadingTracks.forEach { $0.stop() }
        fadingTracks.removeAll()
    }

    func suspend(_ value: Bool) {
        suspended = value
        if value { music?.pause(); stopFades(); stopEffects() }
    }
}
