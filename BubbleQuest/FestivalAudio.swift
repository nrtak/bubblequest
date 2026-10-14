import AVFoundation

final class FestivalAudio {
    private var music: AVAudioPlayer?
    private var effects: [AVAudioPlayer] = []
    private var track = ""
    private var suspended = false
    private var fadingTracks: [AVAudioPlayer] = []

    func update(area: Int, enabled: Bool, volume: Float = 0.22) {
        let name = area % LevelCatalog.originalAreas.count < 2 ? "music-day" : "music-evening"
        if track != name {
            track = name
            if let old = music {
                old.setVolume(0, fadeDuration: 0.8)
                fadingTracks.append(old)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { [weak self, weak old] in
                    old?.stop()
                    self?.fadingTracks.removeAll { $0 === old }
                }
            }
            if let url = Bundle.main.url(forResource: name, withExtension: "wav") {
                music = try? AVAudioPlayer(contentsOf: url)
                music?.numberOfLoops = -1
                music?.volume = 0
                music?.prepareToPlay()
            }
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
        player.volume = volume
        effects.append(player)
        player.play()
    }

    func suspend(_ value: Bool) {
        suspended = value
        if value { music?.pause(); fadingTracks.forEach { $0.stop() }; effects.forEach { $0.stop() } }
    }
}
