import SwiftUI

@main
struct StudioBIApp: App {
    @StateObject private var appState = AppStateManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
