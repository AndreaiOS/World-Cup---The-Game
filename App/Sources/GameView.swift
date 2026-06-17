import SwiftUI
import SpriteKit
import GameCore

struct GameView: View {
    @State private var playerScore = 0
    @State private var opponentScore = 0
    @State private var scene: PenaltyScene = makeScene()

    private static func makeScene() -> PenaltyScene {
        let scene = PenaltyScene(size: CGSize(width: 390, height: 600))
        scene.scaleMode = .resizeFill
        return scene
    }

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: scene)
                .ignoresSafeArea()
            Text("\(playerScore) – \(opponentScore)")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .padding(.top, 8)
                .shadow(radius: 3)
        }
        .onAppear {
            scene.onStateChange = { state in
                playerScore = state.playerScore
                opponentScore = state.opponentScore
            }
        }
    }
}
