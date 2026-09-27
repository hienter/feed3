import SwiftUI
import SwiftData

@main
struct Feed3App: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: [Feeding.self, Baby.self])
    }
}
