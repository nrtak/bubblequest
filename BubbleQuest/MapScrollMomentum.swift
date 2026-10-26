import Foundation
import CoreGraphics

struct MapScrollMomentum {
    private(set) var velocity: CGFloat = 0
    private var lastPosition: CGFloat?
    private var lastTime: TimeInterval?
    var isMoving: Bool { abs(velocity) >= 12 }

    mutating func stop() {
        velocity = 0; lastPosition = nil; lastTime = nil
    }
    mutating func begin(at position: CGFloat, time: TimeInterval) {
        stop()
        guard position.isFinite, time.isFinite else { return }
        lastPosition = position; lastTime = time
    }
    mutating func drag(to position: CGFloat, time: TimeInterval) {
        guard position.isFinite, time.isFinite else { stop(); return }
        defer { lastPosition = position; lastTime = time }
        guard position.isFinite, time.isFinite, let previous = lastPosition, let previousTime = lastTime else { velocity = 0; return }
        let elapsed = time - previousTime
        guard elapsed > 0, elapsed <= 0.12 else { velocity = 0; return }
        let sample = min(2200, max(-2200, (position - previous) / CGFloat(elapsed)))
        velocity = velocity * 0.35 + sample * 0.65
    }
    mutating func end(time: TimeInterval) {
        if !time.isFinite || lastTime.map({ time - $0 > 0.10 || time < $0 }) != false { velocity = 0 }
        lastPosition = nil; lastTime = nil
    }
    mutating func advance(offset: CGFloat, by elapsed: TimeInterval) -> CGFloat {
        guard offset.isFinite, elapsed.isFinite, elapsed > 0, elapsed <= 0.1, isMoving else { stop(); return FestivalMapLayout.scrollOffset(offset.isFinite ? offset : 0) }
        let decayed = velocity * CGFloat(exp(-5.8 * elapsed))
        let proposed = offset + (velocity - decayed) / 5.8
        let result = FestivalMapLayout.scrollOffset(proposed)
        velocity = decayed
        if abs(decayed) < 12 || abs(result - proposed) > 0.001 { stop() }
        return result
    }
}
