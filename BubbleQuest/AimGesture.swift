import Foundation

struct AimGesture {
    static let cancelLine = BubbleGeometry.origin.y + 110
    private(set) var angle = 0.0
    private(set) var isActive = false
    private(set) var shouldCancel = false

    mutating func begin(at point: BubblePoint) {
        isActive = true
        update(at: point)
    }

    mutating func update(at point: BubblePoint) {
        guard isActive else { return }
        shouldCancel = point.y < Self.cancelLine
        guard !shouldCancel else { return }
        angle = min(BubbleGeometry.maxAngle, max(-BubbleGeometry.maxAngle,
                    atan2(point.x - BubbleGeometry.origin.x,
                          max(70, point.y - BubbleGeometry.origin.y))))
    }

    mutating func end(at point: BubblePoint?) -> Double? {
        guard isActive else { return nil }
        let cancelled = shouldCancel || (point.map { $0.y < Self.cancelLine } ?? false)
        defer { cancel() }
        // Lift coordinates only decide cancellation, never change the previewed angle.
        return cancelled ? nil : angle
    }

    mutating func cancel() {
        isActive = false
        shouldCancel = false
    }
}
