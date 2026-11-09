import CoreGraphics

/// A featured roadside scene every five levels, tied to real project progress.
struct FestivalRoadMoment {
    enum Activity: CaseIterable, Hashable { case snacks, drums, kites, greeting }
    enum Landmark: CaseIterable, Hashable { case plaza, lanternArch, bridge }
    let project: FestivalProject
    let step: Int
    var level: Int { project.levels.lowerBound + FestivalProject.thresholds[step] - 1 }
    var position: CGPoint { project.sitePosition(stage: step) }
    var landmarkHeight: CGFloat { FestivalMapLayout.position(level).y + 48 }
    var activity: Activity {
        switch project.displayStyle {
        case .picnic, .stall: return step.isMultiple(of: 2) ? .snacks : .greeting
        case .fireworks: return .drums
        case .kites: return .kites
        case .pinwheels: return step.isMultiple(of: 2) ? .greeting : .drums
        case .lanternWalk: return .greeting
        }
    }
    var landmark: Landmark {
        if [3, 5, 8].contains(project.area) && step.isMultiple(of: 2) { return .bridge }
        return step.isMultiple(of: 2) ? .plaza : .lanternArch
    }
    func isReady(cleared: Int) -> Bool { cleared >= FestivalProject.thresholds[step] }
    /// Earlier stops keep growing with the neighborhood instead of staying half built.
    func constructionStage(cleared: Int) -> Int {
        guard isReady(cleared: cleared) else { return 0 }
        return FestivalProject.thresholds.filter { cleared >= $0 }.count
    }
    func caption(cleared: Int) -> String {
        if step == 3 { return isReady(cleared: cleared) ? "Festival open!" : "Finale • Level \(level + 1)" }
        return isReady(cleared: cleared) ? "Ready! Tap to visit" : "Prepare • Level \(level + 1)"
    }
    static let all: [FestivalRoadMoment] = FestivalProject.all.flatMap { project in
        (0..<4).map { FestivalRoadMoment(project: project, step: $0) }
    }
    static func near(offset: CGFloat) -> [FestivalRoadMoment] {
        let lower = FestivalMapLayout.viewport.minY - offset - 128
        let upper = FestivalMapLayout.viewport.maxY - offset + 128
        return all.filter { $0.position.y + 100 >= lower && $0.position.y - 30 <= upper }
    }
}
