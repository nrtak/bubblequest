import Foundation

struct OperatorArmPose {
    static let upperLength = 18.0
    static let forearmLength = 24.0
    let shoulder: BubblePoint
    let elbow: BubblePoint
    let hand: BubblePoint

    static func gripping(shoulder: BubblePoint, hand: BubblePoint) -> OperatorArmPose {
        let dx = hand.x - shoulder.x, dy = hand.y - shoulder.y
        let distance = hypot(dx, dy)
        let reach = min(upperLength + forearmLength - 0.001,
                        max(abs(upperLength - forearmLength) + 0.001, distance))
        let angle = atan2(dy, dx)
        let bend = acos(max(-1, min(1, (upperLength * upperLength + reach * reach - forearmLength * forearmLength) / (2 * upperLength * reach))))
        return OperatorArmPose(shoulder: shoulder,
                               elbow: BubblePoint(x: shoulder.x + cos(angle - bend) * upperLength,
                                                  y: shoulder.y + sin(angle - bend) * upperLength),
                               hand: BubblePoint(x: shoulder.x + cos(angle) * reach,
                                                 y: shoulder.y + sin(angle) * reach))
    }
}
