import AppKit
import Foundation

@MainActor
final class AppBlocker: NSObject, ObservableObject {
    @Published private(set) var lastBlockedAppName: String?
    @Published private(set) var blockedCount = 0
    @Published private(set) var lastBlockedWebsiteHost: String?
    @Published private(set) var blockedWebsiteCount = 0
    @Published private(set) var websiteControlIssue: String?

    private var allowedApplicationMatcher = AllowedApplicationMatcher(applications: [])
    private var allowedWebsites: [AllowedWebsite] = []
    private var enforcementTask: Task<Void, Never>?
    private var isObservingActivations = false
    private var lastNoticeAt: [String: Date] = [:]

    private let safeSystemApps: Set<String> = [
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
        case inaccessible(String)
    }

    private let supportedBrowsers: [String: BrowserKind] = [
        "com.apple.Safari": .safari,
        "com.google.Chrome": .chromium,
        "com.microsoft.edgemac": .chromium,
        "company.thebrowser.Browser": .chromium,
        "com.brave.Browser": .chromium,
        "com.operasoftware.Opera": .chromium
    ]

    func start(allowing apps: [AllowedApp], websites: [AllowedWebsite]) {
        stop()
        allowedApplicationMatcher = AllowedApplicationMatcher(applications: apps)
        allowedWebsites = websites
        blockedCount = 0
        blockedWebsiteCount = 0
        lastBlockedAppName = nil
        lastBlockedWebsiteHost = nil
        websiteControlIssue = nil

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        isObservingActivations = true

        enforceNow()
        enforcementTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(700))
                guard !Task.isCancelled else { break }
                self?.enforceNow()
            }
        }
    }

    func stop() {
        enforcementTask?.cancel()
        enforcementTask = nil
        if isObservingActivations {
            NSWorkspace.shared.notificationCenter.removeObserver(
                self,
                name: NSWorkspace.didActivateApplicationNotification,
                object: nil
            )
            isObservingActivations = false
        }
        allowedApplicationMatcher = AllowedApplicationMatcher(applications: [])
        allowedWebsites.removeAll()
        lastNoticeAt.removeAll()
        websiteControlIssue = nil
    }

    private func enforceNow() {
        let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier

        for app in NSWorkspace.shared.runningApplications {
            guard app.processIdentifier != ownProcessIdentifier,
                  app.activationPolicy == .regular,
                  !app.isHidden,
                  !isAllowed(app) else { continue }
            block(app)
        }

        enforceWebsiteIfNeeded()
    }

    @objc private func workspaceDidActivate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              app.activationPolicy == .regular,
              !isAllowed(app) else { return }
        block(app)
    }

    private func block(_ app: NSRunningApplication) {
        let displayName = app.localizedName ?? "未命名应用"
        let noticeKey = app.bundleIdentifier ?? displayName
        let now = Date()
        if now.timeIntervalSince(lastNoticeAt[noticeKey] ?? .distantPast) > 2 {
            lastBlockedAppName = displayName
            blockedCount += 1
            lastNoticeAt[noticeKey] = now
        }

        app.hide()
    }

    private func enforceWebsiteIfNeeded() {
        guard let browser = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = browser.bundleIdentifier,
              let kind = supportedBrowsers[bundleIdentifier],
              isAllowed(browser) else { return }

        switch currentPage(for: bundleIdentifier, kind: kind) {
        case .noPage:
            return
        case .inaccessible(let message):
            websiteControlIssue = message
            recordBlockedWebsite("无法读取当前标签页")
            browser.hide()
        case .page(let rawURL):
            enforce(
                rawURL: rawURL,
                in: browser,
                bundleIdentifier: bundleIdentifier,
                kind: kind
            )
        }
    }

    private func enforce(
        rawURL: String,
        in browser: NSRunningApplication,
        bundleIdentifier: String,
        kind: BrowserKind
    ) {
        guard let url = URL(string: rawURL), let scheme = url.scheme?.lowercased() else {
            blockWebsite("无效页面", in: browser, bundleIdentifier: bundleIdentifier, kind: kind)
            return
        }

        if isInternallyAllowed(url) {
            websiteControlIssue = nil
            return
        }

        guard ["http", "https"].contains(scheme),
              let host = url.host?.lowercased() else {
            blockWebsite("\(scheme) 页面", in: browser, bundleIdentifier: bundleIdentifier, kind: kind)
            return
        }

        guard !allowedWebsites.contains(where: { $0.allows(host: host) }) else {
            websiteControlIssue = nil
            return
        }

        blockWebsite(host, in: browser, bundleIdentifier: bundleIdentifier, kind: kind)
    }

    private func blockWebsite(
        _ label: String,
        in browser: NSRunningApplication,
        bundleIdentifier: String,
        kind: BrowserKind
    ) {
        recordBlockedWebsite(label)
        if !redirectToBlank(bundleIdentifier: bundleIdentifier, kind: kind) {
            browser.hide()
        }
    }

    private func recordBlockedWebsite(_ label: String) {
        let noticeKey = "website:\(label)"
        let now = Date()
        guard now.timeIntervalSince(lastNoticeAt[noticeKey] ?? .distantPast) > 2 else { return }

        lastBlockedWebsiteHost = label
        blockedWebsiteCount += 1
        lastNoticeAt[noticeKey] = now
    }

    private func isInternallyAllowed(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return ["about", "chrome", "edge", "brave", "arc", "file"].contains(scheme)
    }

    private func currentPage(for bundleIdentifier: String, kind: BrowserKind) -> BrowserPageResult {
        let tabReference = kind == .safari ? "current tab of front window" : "active tab of front window"
        let source = """
        tell application id "\(bundleIdentifier)"
            if (count of windows) is 0 then return ""
            return URL of \(tabReference)
        end tell
        """

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: source) else {
            return .inaccessible("暂时无法创建浏览器控制脚本。")
        }
        let result = appleScript.executeAndReturnError(&error)
        if let error, error.count > 0 {
            let number = error["NSAppleScriptErrorNumber"] as? Int
            let message = number == -1743
                ? "请允许森时控制当前浏览器，网页白名单才能生效。"
                : "暂时无法读取当前浏览器标签页。"
            return .inaccessible(message)
        }

        websiteControlIssue = nil
        guard let value = result.stringValue, !value.isEmpty else { return .noPage }
        return .page(value)
    }

    @discardableResult
    private func redirectToBlank(bundleIdentifier: String, kind: BrowserKind) -> Bool {
        let tabReference = kind == .safari ? "current tab of front window" : "active tab of front window"
        let source = """
        tell application id "\(bundleIdentifier)"
            if (count of windows) > 0 then set URL of \(tabReference) to "about:blank"
        end tell
        """
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: source) else {
            websiteControlIssue = "网页已识别，但暂时无法创建浏览器控制脚本。"
            return false
        }
        appleScript.executeAndReturnError(&error)
        if let error, error.count > 0 {
            websiteControlIssue = "网页已识别，但暂时无法清空这个标签页。"
            return false
        }
        websiteControlIssue = nil
        return true
    }

    private func isAllowed(_ app: NSRunningApplication) -> Bool {
        if isTrustedSystemApp(app) { return true }
        return allowedApplicationMatcher.allows(
            bundleIdentifier: app.bundleIdentifier,
            path: app.bundleURL?.path
        )
    }

    private func isTrustedSystemApp(_ app: NSRunningApplication) -> Bool {
        guard let bundleIdentifier = app.bundleIdentifier,
              safeSystemApps.contains(bundleIdentifier),
              let path = app.bundleURL?.path else { return false }
        let canonicalPath = AllowedApplicationMatcher.canonicalPath(path)
        return canonicalPath.hasPrefix("/System/Library/")
            || canonicalPath.hasPrefix("/System/Applications/")
    }
}
