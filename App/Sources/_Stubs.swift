import SwiftUI

struct MenuView: View {
    let model: AppModel
    var body: some View { Text("Menu").onAppear { } }
}
struct NationSelectView: View {
    let model: AppModel
    var body: some View { Text("Nation Select") }
}
struct TournamentHubView: View {
    let model: AppModel
    var body: some View { Text("Hub") }
}
struct MatchView: View {
    let model: AppModel
    var body: some View { Text("Match") }
}
