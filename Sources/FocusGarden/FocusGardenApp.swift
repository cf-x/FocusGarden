import AppKit
import SwiftUI

@main
struct FocusGardenApp: App {
    @StateObject private var state = AppState()

    init() {
        if let iconURL = Bundle.main.url(forResource: "FocusGarden", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = icon
        }
    }

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
            HStack(spacing: 4) {
                Image(systemName: state.isSessionActive ? "timer" : "leaf.fill")
                if state.isSessionActive && state.showRemainingTimeInMenuBar {
                    Text(state.formattedRemaining)
                        .monospacedDigit()
                }
            }
            .accessibilityLabel(
                state.isSessionActive
                    ? "森时，剩余 \(state.formattedRemaining)"
                    : "森时"
            )
        }
        .menuBarExtraStyle(.window)
    }
}
