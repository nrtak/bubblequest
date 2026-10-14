import Foundation

struct OperatorArmPose {
    let shoulder: BubblePoint
    let elbow: BubblePoint
    let hand: BubblePoint
    static let upperLength = 24.0
    static let forearmLength = 26.0

    static func aiming(_ angle: Double) -> OperatorArmPose {
        let rotation = -min(BubbleGeometry.maxAngle, max(-BubbleGeometry.maxAngle, angle)) * 2.5
        let hand = BubblePoint(x: 280 - sin(rotation) * 18, y: 173 + cos(rotation) * 18)
        let shoulder = BubblePoint(x: 290, y: 196)
        let dx = hand.x - shoulder.x, dy = hand.y - shoulder.y
        let distance = hypot(dx, dy)
        let along = (upperLength * upperLength - forearmLength * forearmLength + distance * distance) / (2 * distance)
        let perpendicular = sqrt(max(0, upperLength * upperLength - along * along))
        let elbow = BubblePoint(x: shoulder.x + along * dx / distance - perpendicular * dy / distance,
                                y: shoulder.y + along * dy / distance + perpendicular * dx / distance)
        return OperatorArmPose(shoulder: shoulder, elbow: elbow, hand: hand)
    }
}
