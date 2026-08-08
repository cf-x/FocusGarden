import SwiftUI

@main
struct FocusGardenApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .frame(minWidth: 920, minHeight: 620)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1060, height: 700)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(state)
        } label: {
            Label(
                state.isSessionActive ? state.formattedRemaining : "森时",
                systemImage: state.isSessionActive ? "timer" : "leaf.fill"
            )
        }
        .menuBarExtraStyle(.window)
    }
}
