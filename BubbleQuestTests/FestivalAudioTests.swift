import XCTest
@testable import BubbleQuest

final class FestivalAudioTests: XCTestCase {
    private final class Player: FestivalMusicPlaying {
        var numberOfLoops = 0
        var volume: Float = 0
        var isPlaying = false
        var stops = 0
        func play() -> Bool { isPlaying = true; return true }
        func prepareToPlay() -> Bool { true }
        func pause() { isPlaying = false }
        func stop() { isPlaying = false; stops += 1 }
        func setVolume(_ volume: Float, fadeDuration: TimeInterval) { self.volume = volume }
    }

    @MainActor
    func testMuteStillPausesTheOldTrackWhenTheReplacementCannotLoad() {
        let player = Player()
        let audio = FestivalAudio { $0 == "known" ? player : nil }
        audio.update(name: "known", enabled: true)
        XCTAssertTrue(player.isPlaying)
        audio.update(name: "missing", enabled: false)
        XCTAssertFalse(player.isPlaying)
        audio.update(name: "known", enabled: true)
        XCTAssertTrue(player.isPlaying, "Unmuting resumes the retained valid track")
    }

    @MainActor
    func testZeroVolumeImmediatelySilencesBothSidesOfACrossfade() {
        let old = Player(), current = Player()
        let audio = FestivalAudio { $0 == "old" ? old : current }
        audio.update(name: "old", enabled: true)
        audio.update(name: "current", enabled: true)
        XCTAssertTrue(old.isPlaying, "Outgoing music remains active during its fade")
        XCTAssertTrue(current.isPlaying)
        audio.update(name: "current", enabled: true, volume: 0)
        XCTAssertFalse(old.isPlaying)
        XCTAssertFalse(current.isPlaying)
        XCTAssertEqual(old.stops, 1)
    }

    @MainActor
    func testSuspensionAndMalformedVolumeCannotLeaveAnOutgoingTrackAudible() {
        let first = Player(), second = Player()
        let audio = FestivalAudio { $0 == "first" ? first : $0 == "second" ? second : nil }
        audio.update(name: "first", enabled: true)
        audio.update(name: "second", enabled: true)
        audio.update(name: "missing", enabled: true, volume: .nan)
        XCTAssertFalse(first.isPlaying)
        XCTAssertFalse(second.isPlaying)
        audio.update(name: "second", enabled: true, volume: 4)
        XCTAssertEqual(second.volume, 1)
        audio.suspend(true)
        audio.update(name: "first", enabled: true)
        XCTAssertFalse(first.isPlaying)
        XCTAssertFalse(second.isPlaying)
        audio.suspend(false)
        audio.update(name: "first", enabled: true)
        XCTAssertTrue(first.isPlaying)
    }
}
