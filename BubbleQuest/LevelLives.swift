import Foundation

struct LevelLives: Codable, Equatable {
    static let capacity = 5
    static let refillInterval: TimeInterval = 5 * 60
    private(set) var available = LevelLives.capacity
    private(set) var nextRefill: Date?

    mutating func refresh(at now: Date) {
        available = min(Self.capacity, max(0, available))
        guard available < Self.capacity else { nextRefill = nil; return }
        guard let next = nextRefill, next.timeIntervalSince1970.isFinite,
              next.timeIntervalSince(now) <= Self.refillInterval else {
            nextRefill = now.addingTimeInterval(Self.refillInterval); return
        }
        guard now >= next else { return }
        let elapsed = min(Self.refillInterval * Double(Self.capacity), now.timeIntervalSince(next))
        let earned = min(Self.capacity, Int(elapsed / Self.refillInterval) + 1)
        available = min(Self.capacity, available + earned)
        nextRefill = available == Self.capacity ? nil : next.addingTimeInterval(Double(earned) * Self.refillInterval)
    }

    @discardableResult
    mutating func consume(at now: Date) -> Bool {
        refresh(at: now)
        guard available > 0 else { return false }
        available -= 1
        if nextRefill == nil { nextRefill = now.addingTimeInterval(Self.refillInterval) }
        return true
    }

    func secondsUntilRefill(at now: Date) -> Int {
        guard available < Self.capacity, let next = nextRefill else { return 0 }
        return Int(ceil(max(0, min(Self.refillInterval, next.timeIntervalSince(now)))))
    }
    func countdown(at now: Date) -> String {
        let seconds = secondsUntilRefill(at: now)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
