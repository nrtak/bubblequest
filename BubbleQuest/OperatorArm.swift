import Foundation

struct OperatorArmPose {
    static let upperLength = 18.0
    static let forearmLength = 18.0
    static let palmLength = 19.0 * 32 / 72
    let shoulder: BubblePoint
    let elbow: BubblePoint
    let hand: BubblePoint

    static func gripping(shoulder: BubblePoint, hand: BubblePoint, palmLength: Double = 0) -> OperatorArmPose {
        let dx = hand.x - shoulder.x, dy = hand.y - shoulder.y
        let distance = hypot(dx, dy)
        let lowerLength = forearmLength + palmLength
        let reach = min(upperLength + lowerLength - 0.001,
                        max(abs(upperLength - lowerLength) + 0.001, distance))
        let angle = atan2(dy, dx)
        let bend = acos(max(-1, min(1, (upperLength * upperLength + reach * reach - lowerLength * lowerLength) / (2 * upperLength * reach))))
        // The wheel-side elbow stays outside the torso, below the sleeve.
        let elbow = BubblePoint(x: shoulder.x + cos(angle - bend) * upperLength,
                                y: shoulder.y + sin(angle - bend) * upperLength)
        let contact = BubblePoint(x: shoulder.x + cos(angle) * reach,
                                  y: shoulder.y + sin(angle) * reach)
        return OperatorArmPose(shoulder: shoulder, elbow: elbow,
                               hand: BubblePoint(x: elbow.x + (contact.x - elbow.x) * forearmLength / lowerLength,
                                                 y: elbow.y + (contact.y - elbow.y) * forearmLength / lowerLength))
    }
}
