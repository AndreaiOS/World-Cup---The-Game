import SwiftUI
import GameCore

struct NationSelectView: View {
    @ObservedObject var model: AppModel

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.30, blue: 0.16).ignoresSafeArea()
            VStack(spacing: 0) {
                Text("CHOOSE YOUR NATION")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .padding(.vertical, 16)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(model.nations.sorted { $0.strength > $1.strength }, id: \.id) { nation in
                            Button { model.startTournament(nationId: nation.id) } label: {
                                VStack(spacing: 6) {
                                    Text(nation.flag).font(.system(size: 40))
                                    Text(nation.name)
                                        .font(.caption2.bold())
                                        .foregroundColor(.white)
                                        .lineLimit(1).minimumScaleFactor(0.7)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                Button("Back") { model.abandonToMenu() }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.vertical, 12)
            }
        }
    }
}
