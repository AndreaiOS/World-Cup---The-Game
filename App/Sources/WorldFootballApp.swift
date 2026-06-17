import SwiftUI

@main
struct WorldFootballApp: App {
    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.green.opacity(0.3).ignoresSafeArea()
                Text("World Football 2026")
                    .font(.title.bold())
            }
        }
    }
}
