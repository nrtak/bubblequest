import SwiftUI
import SpriteKit

@main
struct BubbleQuestApp: App {
    var body: some Scene {
        WindowGroup { GameView().preferredColorScheme(.dark) }
    }
}

struct GameView: View {
    @State private var scene = FestivalScene(size: CGSize(width: 390, height: 844))
    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
            .onAppear { scene.scaleMode = .aspectFit }
    }
}
