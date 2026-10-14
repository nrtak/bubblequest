import Foundation

struct OperatorArmPose {
    let shoulder: BubblePoint
    let elbow: BubblePoint
    let hand: BubblePoint
    static let upperLength = 28.0
    static let forearmLength = 28.0

    static func resting(shoulder: BubblePoint, hand: BubblePoint) -> OperatorArmPose {
        // A compact, fixed bend. Aiming changes only the wheel beneath the hand.
        OperatorArmPose(shoulder: shoulder,
                        elbow: BubblePoint(x: shoulder.x - 3, y: shoulder.y - 12), hand: hand)
    }

    static func aiming(_ angle: Double) -> OperatorArmPose {
        let rotation = -min(BubbleGeometry.maxAngle, max(-BubbleGeometry.maxAngle, angle)) * 2.5
        let hand = BubblePoint(x: 280 - sin(rotation) * 18, y: 173 + cos(rotation) * 18)
        return connecting(shoulder: BubblePoint(x: 290, y: 188), hand: hand)
    }

    static func connecting(shoulder: BubblePoint, hand: BubblePoint) -> OperatorArmPose {
        let dx = hand.x - shoulder.x, dy = hand.y - shoulder.y
        if hypot(dx, dy) < 0.0001 {
            return OperatorArmPose(shoulder: shoulder, elbow: BubblePoint(x: shoulder.x + upperLength, y: shoulder.y), hand: hand)
        }
        let distance = max(0.0001, hypot(dx, dy))
        let along = (upperLength * upperLength - forearmLength * forearmLength + distance * distance) / (2 * distance)
        let perpendicular = sqrt(max(0, upperLength * upperLength - along * along))
        let elbow = BubblePoint(x: shoulder.x + along * dx / distance - perpendicular * dy / distance,
                                y: shoulder.y + along * dy / distance + perpendicular * dx / distance)
        return OperatorArmPose(shoulder: shoulder, elbow: elbow, hand: hand)
    }
}
