import Foundation

struct OperatorArmPose {
    let shoulder: BubblePoint
    let elbow: BubblePoint
    let hand: BubblePoint
    static func resting(shoulder: BubblePoint, hand: BubblePoint) -> OperatorArmPose {
        // A compact, fixed bend. Aiming changes only the wheel beneath the hand.
        OperatorArmPose(shoulder: shoulder,
                        elbow: BubblePoint(x: shoulder.x - 3, y: shoulder.y - 12), hand: hand)
    }

}
