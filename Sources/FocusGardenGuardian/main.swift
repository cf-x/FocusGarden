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

private struct GuardianApplicationIdentity {
    let bundleIdentifier: String?
    let canonicalPath: String
}

private struct GuardianSession: Codable {
    let startedAt: Date
    let endsAt: Date
    let durationMinutes: Int
    let allowedApps: [GuardianAllowedApp]
    let allowedWebsites: [GuardianAllowedWebsite]?

    var hasValidTiming: Bool {
        guard (5...120).contains(durationMinutes) else { return false }
        let expectedDuration = TimeInterval(durationMinutes * 60)
        let persistedDuration = endsAt.timeIntervalSince(startedAt)
        return persistedDuration > 0 && abs(persistedDuration - expectedDuration) < 1
    }
}

@MainActor
private final class FocusGuardian {
    private let mainBundleIdentifier = "dev.local.focusgarden.mac"
    private let preferences = UserDefaults(suiteName: "dev.local.focusgarden.mac")!
    private let hotKey = GuardianHotKey()
    private var timer: Timer?
    private var lastHandledEndDate: Date?

    private let safeSystemBundleIdentifiers: Set<String> = [
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

    private enum BrowserPageResult {
        case noPage
        case page(String)
        case inaccessible
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
        guard let data = preferences.data(forKey: "focusGarden.activeSession.v1") else { return nil }
        guard let session = try? JSONDecoder().decode(GuardianSession.self, from: data),
              session.hasValidTiming else {
            preferences.removeObject(forKey: "focusGarden.activeSession.v1")
            return nil
        }
        return session
    }

    private func enforce() {
        guard let session = sessionSnapshot() else {
            lastHandledEndDate = nil
            return
        }

        if session.endsAt <= Date() {
            if !mainAppIsRunning, lastHandledEndDate != session.endsAt {
                lastHandledEndDate = session.endsAt
                openMainApplication(activating: false, backgroundCompletion: true)
            }
            return
        }

        let allowedApplications = session.allowedApps.map {
            GuardianApplicationIdentity(
                bundleIdentifier: $0.bundleIdentifier,
                canonicalPath: canonicalPath($0.path)
            )
        }

        for app in NSWorkspace.shared.runningApplications {
            guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  app.activationPolicy == .regular,
                  !app.isHidden,
                  !isAllowed(app, applications: allowedApplications) else { continue }
            app.hide()
        }

        if !mainAppIsRunning {
            enforceWebsite(session.allowedWebsites ?? [], applications: allowedApplications)
        }
    }

    private func isAllowed(
        _ app: NSRunningApplication,
        applications: [GuardianApplicationIdentity]
    ) -> Bool {
        if isTrustedMainApplication(app) || isTrustedSystemApplication(app) { return true }
        guard let candidatePath = app.bundleURL?.path else { return false }
        let candidateCanonicalPath = canonicalPath(candidatePath)
        return applications.contains { application in
            guard application.canonicalPath == candidateCanonicalPath else { return false }
            guard let expectedIdentifier = application.bundleIdentifier else { return true }
            return expectedIdentifier == app.bundleIdentifier
        }
    }

    private func enforceWebsite(
        _ websites: [GuardianAllowedWebsite],
        applications: [GuardianApplicationIdentity]
    ) {
        guard let browser = NSWorkspace.shared.frontmostApplication,
              let identifier = browser.bundleIdentifier,
              let kind = supportedBrowsers[identifier],
              isAllowed(browser, applications: applications) else { return }

        switch currentPage(bundleIdentifier: identifier, kind: kind) {
        case .noPage:
            return
        case .inaccessible:
            browser.hide()
        case .page(let rawURL):
            guard shouldBlock(rawURL: rawURL, websites: websites) else { return }
            if !redirectToBlank(bundleIdentifier: identifier, kind: kind) {
                browser.hide()
            }
        }
    }

    private func shouldBlock(rawURL: String, websites: [GuardianAllowedWebsite]) -> Bool {
        guard let url = URL(string: rawURL),
              let scheme = url.scheme?.lowercased() else { return true }
        if ["about", "chrome", "edge", "brave", "arc", "file"].contains(scheme) {
            return false
        }
        guard ["http", "https"].contains(scheme),
              let host = url.host?.lowercased() else { return true }
        return !websites.contains(where: { $0.allows(host: host) })
    }

    private func currentPage(bundleIdentifier: String, kind: BrowserKind) -> BrowserPageResult {
        let tab = kind == .safari ? "current tab of front window" : "active tab of front window"
        let script = """
        tell application id "\(bundleIdentifier)"
            if (count of windows) is 0 then return ""
            return URL of \(tab)
        end tell
        """
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return .inaccessible }
        let value = appleScript.executeAndReturnError(&error).stringValue
        if let error, error.count > 0 { return .inaccessible }
        guard let value, !value.isEmpty else { return .noPage }
        return .page(value)
    }

    @discardableResult
    private func redirectToBlank(bundleIdentifier: String, kind: BrowserKind) -> Bool {
        let tab = kind == .safari ? "current tab of front window" : "active tab of front window"
        let script = """
        tell application id "\(bundleIdentifier)"
            if (count of windows) > 0 then set URL of \(tab) to "about:blank"
        end tell
        """
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return false }
        appleScript.executeAndReturnError(&error)
        return error == nil || error?.count == 0
    }

    private func openMainApplication(activating: Bool, backgroundCompletion: Bool) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activating
        if backgroundCompletion {
            configuration.arguments = ["--background-completion"]
        }
        NSWorkspace.shared.openApplication(at: mainApplicationURL, configuration: configuration)
    }

    private var mainApplicationURL: URL {
        var url = Bundle.main.bundleURL
        for _ in 0..<4 {
            url.deleteLastPathComponent()
        }
        return url
    }

    private var mainAppIsRunning: Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: mainBundleIdentifier).contains(
            where: isTrustedMainApplication
        )
    }

    private func isTrustedMainApplication(_ app: NSRunningApplication) -> Bool {
        guard app.bundleIdentifier == mainBundleIdentifier,
              let path = app.bundleURL?.path else { return false }
        return canonicalPath(path) == canonicalPath(mainApplicationURL.path)
    }

    private func isTrustedSystemApplication(_ app: NSRunningApplication) -> Bool {
        guard let identifier = app.bundleIdentifier,
              safeSystemBundleIdentifiers.contains(identifier),
              let path = app.bundleURL?.path else { return false }
        let trustedPath = canonicalPath(path)
        return trustedPath.hasPrefix("/System/Library/")
            || trustedPath.hasPrefix("/System/Applications/")
    }

    private func canonicalPath(_ path: String) -> String {
        URL(fileURLWithPath: path)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
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
