import SwiftUI
import SpriteKit
import GameCore

struct GameView: View {
    @State private var playerScore = 0
    @State private var opponentScore = 0
    @State private var isOver = false
    @State private var playerWon = false
    @State private var sceneID = 0
    @State private var scene: PenaltyScene = makeScene()

    private static func makeScene() -> PenaltyScene {
        let scene = PenaltyScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .aspectFill
        return scene
    }

    private func wire(_ scene: PenaltyScene) {
        scene.onStateChange = { state in
            playerScore = state.playerScore
            opponentScore = state.opponentScore
            isOver = state.isOver
            playerWon = state.winnerIsPlayer ?? false
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: scene)
                .id(sceneID)
                .ignoresSafeArea()
            Text("\(playerScore) – \(opponentScore)")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 24).padding(.vertical, 8)
                .background(.black.opacity(0.35), in: Capsule())
                .padding(.top, 12)

            if isOver {
                VStack(spacing: 16) {
                    Text(playerWon ? "YOU WIN!" : "YOU LOSE")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Button("Play Again") { restart() }
                        .font(.title2.bold())
                        .padding(.horizontal, 28).padding(.vertical, 12)
                        .background(.white).foregroundColor(.black)
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black.opacity(0.55))
                .ignoresSafeArea()
            }
        }
        .onAppear { wire(scene) }
    }

    private func restart() {
        let fresh = Self.makeScene()
        wire(fresh)
        scene = fresh
        sceneID += 1
        playerScore = 0; opponentScore = 0; isOver = false; playerWon = false
    }
}
