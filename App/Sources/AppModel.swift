import SwiftUI
import GameCore

@MainActor
final class AppModel: ObservableObject {
    enum Screen: Equatable { case menu, nationSelect, hub, match }

    @Published var screen: Screen = .menu
    @Published private(set) var save: TournamentSave?

    let nations: [Nation]
    let groups: [FootballGroup]
    private let byId: [String: Nation]
    private let store: SaveStore
    private let saveURL: URL

    init() {
        nations = (try? DataStore.loadNations()) ?? []
        groups = (try? DataStore.loadGroups()) ?? []
        byId = Dictionary(uniqueKeysWithValues: nations.map { ($0.id, $0) })
        saveURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tournament.json")
        store = SaveStore(url: saveURL)
        do { save = try store.load() } catch { save = nil }
    }

    var hasSave: Bool { save != nil }

    func nation(_ id: String?) -> Nation? { id.flatMap { byId[$0] } }

    var snapshot: TournamentSnapshot? {
        guard let save else { return nil }
        return TournamentEngine.snapshot(nations: nations, groups: groups, save: save)
    }

    func goToNationSelect() { screen = .nationSelect }

    func startTournament(nationId: String) {
        save = TournamentSave(playerNationId: nationId, seed: UInt64.random(in: 1...999_999))
        persist()
        screen = .hub
    }

    func continueTournament() { screen = .hub }

    func playMatch() { screen = .match }

    /// A per-match seed for the interactive shootout's own AI randomness.
    /// Independent of the tournament simulation; only affects how the played
    /// match feels, not the recorded result.
    var matchSeed: UInt64 {
        guard let save else { return 1 }
        return save.seed &+ UInt64(save.playerResults.count) &+ 1
    }

    func recordMatch(playerScore: Int, opponentScore: Int) {
        guard var s = save, let oppId = snapshot?.opponentId else { return }
        s.playerResults.append(MatchResult(homeId: s.playerNationId, awayId: oppId,
                                           homeScore: playerScore, awayScore: opponentScore))
        save = s
        persist()
        screen = .hub
    }

    func abandonToMenu() { screen = .menu }

    func resetAndChooseNation() {
        save = nil
        try? FileManager.default.removeItem(at: saveURL)
        screen = .nationSelect
    }

    private func persist() {
        guard let save else { return }
        try? store.save(save)
    }
}
