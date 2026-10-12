import AVFoundation

final class FestivalAudio {
    private var music: AVAudioPlayer?
    private var effects: [AVAudioPlayer] = []
    private var track = ""
    private var suspended = false

    func update(area: Int, enabled: Bool) {
        let name = area < 2 ? "music-day" : "music-evening"
        if track != name {
            track = name
            music?.stop()
            if let url = Bundle.main.url(forResource: name, withExtension: "wav") {
                music = try? AVAudioPlayer(contentsOf: url)
                music?.numberOfLoops = -1
                music?.volume = 0.22
                music?.prepareToPlay()
            }
        }
        if enabled && !suspended { music?.play() } else { music?.pause() }
    }

    func effect(_ name: String, enabled: Bool) {
        guard enabled, !suspended,
              let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        effects.removeAll { !$0.isPlaying }
        player.volume = 0.6
        effects.append(player)
        player.play()
    }

    func suspend(_ value: Bool) {
        suspended = value
        if value { music?.pause(); effects.forEach { $0.stop() } }
    }
}
