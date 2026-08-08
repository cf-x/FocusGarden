import AppKit
import Carbon.HIToolbox
import Foundation

private struct GuardianAllowedApp: Codable {
    let id: String
    let name: String
    let bundleIdentifier: String?
    let path: String
}

private struct GuardianAllowedWebsite: Codable {
    let id: String
    let host: String

    func allows(host candidate: String) -> Bool {
        let normalized = candidate.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return normalized == host || normalized.hasSuffix(".\(host)")
    }
}

private struct GuardianSession: Codable {
    let startedAt: Date
    let endsAt: Date
    let durationMinutes: Int
    let allowedApps: [GuardianAllowedApp]
    let allowedWebsites: [GuardianAllowedWebsite]?
}

@MainActor
private final class FocusGuardian {
    private let preferences = UserDefaults(suiteName: "dev.local.focusgarden")!
    private let hotKey = GuardianHotKey()
    private var timer: Timer?
    private var lastHandledEndDate: Date?

    private let safeBundleIdentifiers: Set<String> = [
        "dev.local.focusgarden",
        "dev.local.focusgarden.guardian",
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.systemuiserver",
        "com.apple.loginwindow",
        "com.apple.notificationcenterui"
    ]

    private enum BrowserKind: Equatable {
        case safari
        case chromium
    }

    private let supportedBrowsers: [String: BrowserKind] = [
        "com.apple.Safari": .safari,
        "com.google.Chrome": .chromium,
        "com.microsoft.edgemac": .chromium,
        "company.thebrowser.Browser": .chromium,
        "com.brave.Browser": .chromium,
        "com.operasoftware.Opera": .chromium
    ]

    func start() {
        ensureHotKey()
        enforce()
        timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.ensureHotKey()
                self?.enforce()
            }
        }
    }

    private func ensureHotKey() {
        hotKey.registerIfNeeded {
            self.openMainApplication(activating: true, backgroundCompletion: false)
        }
    }

    private func sessionSnapshot() -> GuardianSession? {
        guard let data = preferences.data(forKey: "focusGarden.activeSession.v1"),
              let session = try? JSONDecoder().decode(GuardianSession.self, from: data) else { return nil }
        return session
    }

    private func enforce() {
        guard let session = sessionSnapshot() else {
            lastHandledEndDate = nil
            return
        }

        if session.endsAt <= Date() {
            let mainAppIsRunning = !NSRunningApplication
                .runningApplications(withBundleIdentifier: "dev.local.focusgarden")
                .isEmpty
            if !mainAppIsRunning, lastHandledEndDate != session.endsAt {
                lastHandledEndDate = session.endsAt
                openMainApplication(activating: false, backgroundCompletion: true)
            }
            return
        }

        let allowedIdentifiers = Set(session.allowedApps.compactMap(\.bundleIdentifier))
        let allowedPaths = Set(session.allowedApps.map { URL(fileURLWithPath: $0.path).standardizedFileURL.path })

        for app in NSWorkspace.shared.runningApplications {
            guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  app.activationPolicy == .regular,
                  !app.isHidden,
                  !isAllowed(app, identifiers: allowedIdentifiers, paths: allowedPaths) else { continue }
            app.hide()
        }

        let mainAppIsRunning = !NSRunningApplication
            .runningApplications(withBundleIdentifier: "dev.local.focusgarden")
            .isEmpty
        if !mainAppIsRunning {
            enforceWebsite(session.allowedWebsites ?? [], identifiers: allowedIdentifiers, paths: allowedPaths)
        }
    }

    private func isAllowed(
        _ app: NSRunningApplication,
        identifiers: Set<String>,
        paths: Set<String>
    ) -> Bool {
        if let identifier = app.bundleIdentifier,
           safeBundleIdentifiers.contains(identifier) || identifiers.contains(identifier) {
            return true
        }
        if let path = app.bundleURL?.standardizedFileURL.path, paths.contains(path) {
            return true
        }
        return false
    }

    private func enforceWebsite(
        _ websites: [GuardianAllowedWebsite],
        identifiers: Set<String>,
        paths: Set<String>
    ) {
        guard let browser = NSWorkspace.shared.frontmostApplication,
              let identifier = browser.bundleIdentifier,
              let kind = supportedBrowsers[identifier],
              isAllowed(browser, identifiers: identifiers, paths: paths),
              let rawURL = currentURL(bundleIdentifier: identifier, kind: kind),
              let url = URL(string: rawURL),
              let scheme = url.scheme?.lowercased(),
              !["about", "chrome", "edge", "brave", "arc", "file"].contains(scheme),
              let host = url.host?.lowercased(),
              !websites.contains(where: { $0.allows(host: host) }) else { return }
        redirectToBlank(bundleIdentifier: identifier, kind: kind)
    }

    private func currentURL(bundleIdentifier: String, kind: BrowserKind) -> String? {
        let tab = kind == .safari ? "current tab of front window" : "active tab of front window"
        let script = """
        tell application id "\(bundleIdentifier)"
            if (count of windows) is 0 then return ""
            return URL of \(tab)
        end tell
        """
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        let value = appleScript.executeAndReturnError(&error).stringValue
        return error == nil ? value : nil
    }

    private func redirectToBlank(bundleIdentifier: String, kind: BrowserKind) {
        let tab = kind == .safari ? "current tab of front window" : "active tab of front window"
        let script = """
        tell application id "\(bundleIdentifier)"
            if (count of windows) > 0 then set URL of \(tab) to "about:blank"
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
    }

    private func openMainApplication(activating: Bool, backgroundCompletion: Bool) {
        var mainAppURL = Bundle.main.bundleURL
        for _ in 0..<4 {
            mainAppURL.deleteLastPathComponent()
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activating
        if backgroundCompletion {
            configuration.arguments = ["--background-completion"]
        }
        NSWorkspace.shared.openApplication(at: mainAppURL, configuration: configuration)
    }
}

@MainActor
private final class GuardianHotKey {
    private var reference: EventHotKeyRef?
    private var handlerReference: EventHandlerRef?
    private var action: (() -> Void)?

    func registerIfNeeded(action: @escaping () -> Void) {
        guard reference == nil else { return }
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        guard InstallEventHandler(
            GetApplicationEventTarget(),
            guardianHotKeyHandler,
            1,
            &eventType,
            userData,
            &handlerReference
        ) == noErr else { return }

        let identifier = EventHotKeyID(signature: 0x4647484B, id: 2)
        if RegisterEventHotKey(
            UInt32(kVK_ANSI_F),
            UInt32(cmdKey | shiftKey),
            identifier,
            GetApplicationEventTarget(),
            0,
            &reference
        ) != noErr {
            if let handlerReference {
                RemoveEventHandler(handlerReference)
                self.handlerReference = nil
            }
        }
    }

    fileprivate func invoke() {
        action?()
    }
}

private let guardianHotKeyHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var identifier = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &identifier
    )
    guard status == noErr, identifier.id == 2 else { return status }
    let hotKey = Unmanaged<GuardianHotKey>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in hotKey.invoke() }
    return noErr
}

@main
private enum GuardianMain {
    @MainActor
    static func main() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let guardian = FocusGuardian()
        guardian.start()
        withExtendedLifetime(guardian) {
            NSApplication.shared.run()
        }
    }
}
