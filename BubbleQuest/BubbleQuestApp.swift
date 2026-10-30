import SwiftUI
import SpriteKit

@main
struct BubbleQuestApp: App {
    var body: some Scene {
        WindowGroup { GameView().preferredColorScheme(.dark) }
    }
}

struct GameView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var scene = FestivalScene(size: CGSize(width: 390, height: 844))
    @State private var namingPlayer = false
    @State private var saveName = ""
    @State private var nameCompletion: ((String?) -> Void)?
    var body: some View {
        FestivalGlassView(scene: scene)
            .ignoresSafeArea()
            .onAppear {
                scene.scaleMode = .aspectFit
                scene.requestPlayerName = { initial, completion in
                    saveName = initial
                    nameCompletion = completion
                    namingPlayer = true
                }
            }
            .alert("Name your player save", isPresented: $namingPlayer) {
                TextField("Player / save name", text: $saveName)
                    .textInputAutocapitalization(.words)
                Button("Save") { nameCompletion?(saveName); nameCompletion = nil }
                Button("Cancel", role: .cancel) { nameCompletion?(nil); nameCompletion = nil }
            } message: {
                Text("Use up to 24 letters, numbers, spaces, hyphens or underscores. Each player keeps separate progress on this iPhone.")
            }
            .onChange(of: scenePhase) { _, phase in scene.setActive(phase == .active) }
    }
}
