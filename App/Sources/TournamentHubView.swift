import SwiftUI
import GameCore

struct TournamentHubView: View {
    @ObservedObject var model: AppModel

    private func stageName(_ stage: Stage) -> String {
        switch stage {
        case .group: return "GROUP STAGE"
        case .roundOf32: return "ROUND OF 32"
        case .roundOf16: return "ROUND OF 16"
        case .quarterFinal: return "QUARTER-FINAL"
        case .semiFinal: return "SEMI-FINAL"
        case .final: return "FINAL"
        }
    }

    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.30, blue: 0.16).ignoresSafeArea()
            if let snap = model.snapshot {
                switch snap.phase {
                case .champion:   resultScreen(title: "CHAMPIONS!", emoji: "🏆", color: .yellow)
                case .eliminated: resultScreen(title: "ELIMINATED", emoji: "😞", color: .red)
                case .playing:    playingScreen(snap)
                }
            } else {
                Text("No tournament").foregroundColor(.white)
            }
        }
    }

    @ViewBuilder
    private func playingScreen(_ snap: TournamentSnapshot) -> some View {
        let you = model.nation(model.save?.playerNationId)
        let opp = model.nation(snap.opponentId)
        VStack(spacing: 20) {
            Text(stageName(snap.stage))
                .font(.headline.bold()).foregroundColor(.white.opacity(0.85))
                .padding(.top, 24)

            HStack(spacing: 16) {
                nationBadge(you)
                Text("vs").font(.title3.bold()).foregroundColor(.white.opacity(0.7))
                nationBadge(opp)
            }
            .padding(.vertical, 8)

            if snap.stage == .group {
                standings(snap.playerGroupStandings)
            }

            Spacer()

            Button("PLAY MATCH") { model.playMatch() }
                .font(.title3.bold())
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(.white).foregroundColor(.green)
                .clipShape(Capsule())
                .padding(.horizontal, 32)
            Button("Quit to menu") { model.abandonToMenu() }
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 24)
        }
    }

    private func nationBadge(_ nation: Nation?) -> some View {
        VStack(spacing: 4) {
            Text(nation?.flag ?? "🏳️").font(.system(size: 44))
            Text(nation?.name ?? "—").font(.caption.bold())
                .foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(width: 110)
    }

    private func standings(_ rows: [GroupStanding]) -> some View {
        VStack(spacing: 6) {
            ForEach(rows, id: \.nationId) { row in
                HStack {
                    Text(model.nation(row.nationId)?.flag ?? "🏳️")
                    Text(model.nation(row.nationId)?.name ?? row.nationId)
                        .font(.caption).foregroundColor(.white).lineLimit(1)
                    Spacer()
                    Text("\(row.wins)-\(row.losses)").font(.caption2).foregroundColor(.white.opacity(0.7))
                    Text("\(row.points) pts").font(.caption.bold()).foregroundColor(.white)
                        .frame(width: 54, alignment: .trailing)
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(row.nationId == model.save?.playerNationId
                            ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 24)
    }

    private func resultScreen(title: String, emoji: String, color: Color) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Text(emoji).font(.system(size: 90))
            Text(title).font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundColor(color)
            if let you = model.nation(model.save?.playerNationId) {
                Text("\(you.flag) \(you.name)").font(.title3.bold()).foregroundColor(.white)
            }
            Text("Score: \(model.totalScore)")
                .font(.title2.bold()).foregroundColor(.white.opacity(0.9))
            Spacer()
            Button("NEW TOURNAMENT") { model.resetAndChooseNation() }
                .font(.title3.bold())
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(.white).foregroundColor(.green).clipShape(Capsule())
                .padding(.horizontal, 32)
            Button("Menu") { model.abandonToMenu() }
                .foregroundColor(.white.opacity(0.7)).padding(.bottom, 24)
        }
    }
}
