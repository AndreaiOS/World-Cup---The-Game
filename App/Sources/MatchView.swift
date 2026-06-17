import SwiftUI
import SpriteKit
import GameCore

struct MatchView: View {
    let model: AppModel
    @State private var playerScore = 0
    @State private var opponentScore = 0
    @State private var scene: PenaltyScene

    init(model: AppModel) {
        self.model = model
        let scene = PenaltyScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .aspectFill
        scene.opponentStrength = model.nation(model.snapshot?.opponentId)?.strength ?? 70
        scene.matchSeed = model.matchSeed
        _scene = State(initialValue: scene)
    }

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: scene)
                .ignoresSafeArea()
            HStack {
                badge(model.nation(model.save?.playerNationId))
                Text("\(playerScore) – \(opponentScore)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 6)
                    .background(.black.opacity(0.35), in: Capsule())
                badge(model.nation(model.snapshot?.opponentId))
            }
            .padding(.top, 12)
        }
        .onAppear {
            scene.onStateChange = { state in
                playerScore = state.playerScore
                opponentScore = state.opponentScore
            }
            scene.onComplete = { p, o, saves in
                model.recordMatch(playerScore: p, opponentScore: o, saves: saves)
            }
        }
    }

    private func badge(_ nation: Nation?) -> some View {
        Text(nation?.flag ?? "🏳️").font(.system(size: 28))
    }
}
