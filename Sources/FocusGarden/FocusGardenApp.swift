import AppKit
import SwiftUI

private let legacyMainBundleIdentifier = "dev.local.focusgarden"
private let currentMainBundleIdentifier = "dev.local.focusgarden.mac"
private let preferencesMigrationMarker = "didMigratePreferencesToMacBundleIdentifier"

@MainActor
private func migrateLegacyPreferencesIfNeeded() {
    guard Bundle.main.bundleIdentifier == currentMainBundleIdentifier else { return }

    let defaults = UserDefaults.standard
    var currentDomain = defaults.persistentDomain(forName: currentMainBundleIdentifier) ?? [:]
    guard currentDomain[preferencesMigrationMarker] as? Bool != true else { return }

    if let legacyDomain = defaults.persistentDomain(forName: legacyMainBundleIdentifier) {
        for (key, value) in legacyDomain where currentDomain[key] == nil {
            currentDomain[key] = value
        }
    }

    currentDomain[preferencesMigrationMarker] = true
    defaults.setPersistentDomain(currentDomain, forName: currentMainBundleIdentifier)
}

@MainActor
private func installApplicationIcon() {
    guard let iconURL = Bundle.main.url(
        forResource: "FocusGardenAppIcon-v9",
        withExtension: "icns"
    ), let icon = NSImage(contentsOf: iconURL) else { return }

    NSApplication.shared.applicationIconImage = icon
    for window in NSApplication.shared.windows {
        window.miniwindowImage = icon
    }
}

@MainActor
private final class FocusGardenAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        installApplicationIcon()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installApplicationIcon()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeMain(_:)),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )
        DispatchQueue.main.async {
            installApplicationIcon()
        }
    }

    @objc private func windowDidBecomeMain(_ notification: Notification) {
        installApplicationIcon()
    }
}

@main
struct FocusGardenApp: App {
    @NSApplicationDelegateAdaptor(FocusGardenAppDelegate.self) private var appDelegate
    @StateObject private var state: AppState

    init() {
        migrateLegacyPreferencesIfNeeded()
        _state = StateObject(wrappedValue: AppState())
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
