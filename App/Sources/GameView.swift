import SwiftUI
import SpriteKit

struct GameView: View {
    @State private var scene = makeScene()

    private static func makeScene() -> PenaltyScene {
        let scene = PenaltyScene(size: CGSize(width: 390, height: 600))
        scene.scaleMode = .resizeFill
        return scene
    }

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: scene)
                .ignoresSafeArea()
            Text("0 – 0")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .padding(.top, 8)
                .shadow(radius: 3)
        }
    }
}
