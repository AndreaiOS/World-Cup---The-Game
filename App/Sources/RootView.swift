import SwiftUI

struct RootView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        Group {
            switch model.screen {
            case .menu:         MenuView(model: model)
            case .nationSelect: NationSelectView(model: model)
            case .hub:          TournamentHubView(model: model)
            case .match:        MatchView(model: model)
            }
        }
        .onAppear { LeaderboardService.shared.authenticate() }
    }
}
