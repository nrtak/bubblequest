import Foundation

/// The opening is a short course, with cues confined to the preview before play.
enum OpeningFestival {
    struct Lesson { let title: String; let cue: String }
    static let lessons: [Lesson] = [
        Lesson(title: "First pops", cue: "Drag to aim, then release to match three."),
        Lesson(title: "Choose your color", cue: "Tap your buddy's bubble to swap the next color."),
        Lesson(title: "Drop a branch", cue: "Pop the bubbles holding up a group to drop it."),
        Lesson(title: "Around the corner", cue: "A wall bounce can reach a different side."),
        Lesson(title: "Set the stage", cue: "Help Hana, your market neighbor, set up her stall."),
        Lesson(title: "A little planning", cue: "Look at the next color before choosing a match."),
        Lesson(title: "A charm hunt", cue: "Build a path toward the glowing charms."),
        Lesson(title: "Reach the targets", cue: "Open a route to the marked bubbles above."),
        Lesson(title: "Through the gap", cue: "Look for an opening into the upper groups."),
        Lesson(title: "Add some color", cue: "Find a route to each marked target."),
        Lesson(title: "Pick your route", cue: "Choose which support to clear first."),
        Lesson(title: "A careful match", cue: "A smaller match can open a bigger opportunity."),
        Lesson(title: "Build a path", cue: "Clear one side to reach the groups behind it."),
        Lesson(title: "Around the edge", cue: "Try a wall bounce around the lower groups."),
        Lesson(title: "Light it up", cue: "Free the lanterns to finish the preparations."),
        Lesson(title: "Make each shot count", cue: "Plan a useful match for both colors in the launcher."),
        Lesson(title: "Gather the charms", cue: "Free the marked charms by matching or dropping them."),
        Lesson(title: "Reach the top", cue: "You only need the marked targets."),
        Lesson(title: "Final preparations", cue: "Look for a support that frees a whole branch."),
        Lesson(title: "Market opening", cue: "Bring Hana's festival stall to life!")
    ]
    static let shotCaps = [12, 12, 14, 14, 14, 15, 14, 15, 13, 14, 18, 17, 18, 17, 17, 16, 17, 16, 16]
    static func lesson(for index: Int) -> Lesson? { lessons.indices.contains(index) ? lessons[index] : nil }
    static func shots(for index: Int, proposed: Int) -> Int {
        shotCaps.indices.contains(index) ? min(proposed, shotCaps[index]) : proposed
    }
}
