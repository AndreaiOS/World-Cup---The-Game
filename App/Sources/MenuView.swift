import SwiftUI

struct MenuView: View {
    @ObservedObject var model: AppModel
    @State private var muted = AudioManager.shared.isMuted

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(colors: [.green, .teal], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                Text("WORLD\nFOOTBALL")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("2026")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                if model.hasSave, let snap = model.snapshot, snap.phase == .playing {
                    Button("CONTINUE") { model.continueTournament() }
                        .buttonStyle(MenuButton(primary: true))
                }
                Button("NEW TOURNAMENT") { model.goToNationSelect() }
                    .buttonStyle(MenuButton(primary: !model.hasSave))
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 32)

            Button {
                muted.toggle()
                AudioManager.shared.isMuted = muted
            } label: {
                Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(16)
            }
        }
    }
}

struct MenuButton: ButtonStyle {
    let primary: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.bold())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(primary ? Color.white : Color.white.opacity(0.2))
            .foregroundColor(primary ? .green : .white)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
