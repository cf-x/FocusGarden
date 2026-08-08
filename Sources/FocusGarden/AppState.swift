import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    @Published var allowedApps: [AllowedApp] = []
    @Published var allowedWebsites: [AllowedWebsite] = []
    @Published var websiteInputError: String?
    @Published private(set) var profiles: [FocusProfile] = []
    @Published private(set) var selectedProfileID: UUID?
    @Published var selectedDuration = 25
    @Published private(set) var isSessionActive = false
    @Published private(set) var remainingSeconds = 25 * 60
    @Published private(set) var sessionStartedAt: Date?
    @Published private(set) var currentDurationMinutes = 25
    @Published private(set) var dewBalance = 0
    @Published private(set) var history: [FocusSessionRecord] = []
    @Published private(set) var notificationEnabled = true
    @Published private(set) var showRemainingTimeInMenuBar = true

    let blocker = AppBlocker()
    let systemIntegration = SystemIntegrationManager()
    let hotKeyManager = GlobalHotKeyManager()

    private let defaults: UserDefaults
    private var endsAt: Date?
    private var tickerTask: Task<Void, Never>?

    private enum Key {
        static let allowedApps = "focusGarden.allowedApps.v1"
        static let selectedDuration = "focusGarden.selectedDuration.v1"
        static let allowedWebsites = "focusGarden.allowedWebsites.v1"
        static let dewBalance = "focusGarden.dewBalance.v1"
        static let history = "focusGarden.history.v1"
        static let activeSession = "focusGarden.activeSession.v1"
        static let profiles = "focusGarden.profiles.v1"
        static let selectedProfileID = "focusGarden.selectedProfileID.v1"
        static let notificationEnabled = "focusGarden.notificationEnabled.v1"
        static let showRemainingTimeInMenuBar = "focusGarden.showRemainingTimeInMenuBar.v1"
    }

    init(defaults: UserDefaults = .standard, resumeActiveSession: Bool = true) {
        self.defaults = defaults
        loadPersistedData()
        remainingSeconds = selectedDuration * 60
        if resumeActiveSession {
            restoreActiveSessionIfNeeded()
        }
        hotKeyManager.register {
            AppActivation.showMainWindow()
        }
    }

    var formattedRemaining: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var progress: Double {
        guard isSessionActive else { return 0 }
        let total = max(1, currentDurationMinutes * 60)
        return min(1, max(0, 1 - Double(remainingSeconds) / Double(total)))
    }

    var projectedReward: Int {
        RewardEngine.reward(for: isSessionActive ? currentDurationMinutes : selectedDuration)
    }

    var selectedProfileName: String {
        profiles.first(where: { $0.id == selectedProfileID })?.name ?? "日常专注"
    }

    var projectedPlant: PlantKind {
        RewardEngine.plant(for: isSessionActive ? currentDurationMinutes : selectedDuration)
    }

    var completedSessions: [FocusSessionRecord] {
        history.filter(\.completed)
    }

    var totalFocusedMinutes: Int {
        completedSessions.reduce(0) { $0 + $1.durationMinutes }
    }

    func setDuration(_ minutes: Int) {
        guard !isSessionActive else { return }
        selectedDuration = min(120, max(5, minutes))
        remainingSeconds = selectedDuration * 60
        defaults.set(selectedDuration, forKey: Key.selectedDuration)
    }

    func chooseApplications() {
        guard !isSessionActive else { return }

        let panel = NSOpenPanel()
        panel.title = "选择专注时允许使用的应用"
        panel.prompt = "加入白名单"
        panel.message = "可多选。Finder 与必要的系统界面会始终保留。"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            let bundle = Bundle(url: url)
            let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent
            let app = AllowedApp(
                name: name,
                bundleIdentifier: bundle?.bundleIdentifier,
                path: url.standardizedFileURL.path
            )
            if !allowedApps.contains(where: { $0.id == app.id }) {
                allowedApps.append(app)
            }
        }
        allowedApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persistAllowedApps()
    }

    func removeAllowedApp(_ app: AllowedApp) {
        guard !isSessionActive else { return }
        allowedApps.removeAll { $0.id == app.id }
        persistAllowedApps()
    }

    @discardableResult
    func addWebsite(_ input: String) -> Bool {
        guard !isSessionActive else { return false }
        guard let website = AllowedWebsite(input: input) else {
            websiteInputError = "请输入域名，例如 notion.so"
            return false
        }
        websiteInputError = nil
        if !allowedWebsites.contains(where: { $0.id == website.id }) {
            allowedWebsites.append(website)
            allowedWebsites.sort { $0.host.localizedCaseInsensitiveCompare($1.host) == .orderedAscending }
            persistAllowedWebsites()
        }
        return true
    }

    func removeAllowedWebsite(_ website: AllowedWebsite) {
        guard !isSessionActive else { return }
        allowedWebsites.removeAll { $0.id == website.id }
        persistAllowedWebsites()
    }

    func selectProfile(_ id: UUID) {
        guard !isSessionActive,
              let profile = profiles.first(where: { $0.id == id }) else { return }
        selectedProfileID = profile.id
        allowedApps = profile.allowedApps
        allowedWebsites = profile.allowedWebsites
        defaults.set(profile.id.uuidString, forKey: Key.selectedProfileID)
        persistAllowedApps(syncProfile: false)
        persistAllowedWebsites(syncProfile: false)
    }

    @discardableResult
    func createProfile(named rawName: String, copyingCurrent: Bool = false) -> Bool {
        guard !isSessionActive else { return false }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        let profile = FocusProfile(
            name: name,
            allowedApps: copyingCurrent ? allowedApps : [],
            allowedWebsites: copyingCurrent ? allowedWebsites : []
        )
        profiles.append(profile)
        profiles.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persistProfiles()
        selectProfile(profile.id)
        return true
    }

    func renameProfile(_ id: UUID, to rawName: String) {
        guard !isSessionActive,
              let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        profiles[index].name = name
        persistProfiles()
    }

    func deleteProfile(_ id: UUID) {
        guard !isSessionActive, profiles.count > 1 else { return }
        profiles.removeAll { $0.id == id }
        persistProfiles()
        if selectedProfileID == id, let replacement = profiles.first {
            selectProfile(replacement.id)
        }
    }

    func startSession() {
        guard !isSessionActive else { return }
        let now = Date()
        sessionStartedAt = now
        currentDurationMinutes = selectedDuration
        remainingSeconds = currentDurationMinutes * 60
        endsAt = now.addingTimeInterval(TimeInterval(remainingSeconds))
        isSessionActive = true
        if notificationEnabled {
            CompletionNotifier.shared.requestAuthorization()
        }

        persistActiveSession()
        blocker.start(allowing: allowedApps, websites: allowedWebsites)
        startTicker()
    }

    func abandonSession() {
        guard isSessionActive, let startedAt = sessionStartedAt else { return }
        let record = FocusSessionRecord(
            startedAt: startedAt,
            durationMinutes: currentDurationMinutes,
            completed: false,
            earnedDew: 0,
            plant: RewardEngine.plant(for: currentDurationMinutes)
        )
        history.insert(record, at: 0)
        persistHistory()
        endActiveState()
    }

    func setNotificationEnabled(_ enabled: Bool) {
        notificationEnabled = enabled
        defaults.set(enabled, forKey: Key.notificationEnabled)
        if enabled {
            CompletionNotifier.shared.requestAuthorization()
        }
    }

    func setShowRemainingTimeInMenuBar(_ enabled: Bool) {
        showRemainingTimeInMenuBar = enabled
        defaults.set(enabled, forKey: Key.showRemainingTimeInMenuBar)
    }

    func resetAllLocalData() {
        guard !isSessionActive else { return }
        allowedApps = []
        allowedWebsites = []
        websiteInputError = nil
        history = []
        dewBalance = 0
        notificationEnabled = true
        showRemainingTimeInMenuBar = true
        selectedDuration = 25
        remainingSeconds = 25 * 60
        profiles = []
        selectedProfileID = nil
        [Key.allowedApps, Key.allowedWebsites, Key.selectedDuration, Key.dewBalance, Key.history, Key.activeSession, Key.profiles, Key.selectedProfileID, Key.notificationEnabled, Key.showRemainingTimeInMenuBar]
            .forEach(defaults.removeObject(forKey:))
    }

    private func startTicker() {
        tickerTask?.cancel()
        tickerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.tick()
                guard self?.isSessionActive == true else { break }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func tick() {
        guard isSessionActive, let endsAt else { return }
        remainingSeconds = max(0, Int(ceil(endsAt.timeIntervalSinceNow)))
        if remainingSeconds == 0 {
            completeSession()
        }
    }

    private func completeSession() {
        guard let startedAt = sessionStartedAt else { return }
        let reward = RewardEngine.reward(for: currentDurationMinutes)
        let record = FocusSessionRecord(
            startedAt: startedAt,
            durationMinutes: currentDurationMinutes,
            completed: true,
            earnedDew: reward,
            plant: RewardEngine.plant(for: currentDurationMinutes)
        )
        history.insert(record, at: 0)
        dewBalance += reward
        persistHistory()
        defaults.set(dewBalance, forKey: Key.dewBalance)
        endActiveState()
        if notificationEnabled {
            CompletionNotifier.shared.sendCompletion(
                plant: record.plant,
                minutes: record.durationMinutes,
                reward: record.earnedDew
            )
        }
    }

    private func endActiveState() {
        tickerTask?.cancel()
        tickerTask = nil
        blocker.stop()
        isSessionActive = false
        sessionStartedAt = nil
        endsAt = nil
        remainingSeconds = selectedDuration * 60
        defaults.removeObject(forKey: Key.activeSession)
    }

    private func loadPersistedData() {
        if let data = defaults.data(forKey: Key.allowedApps),
           let decoded = try? JSONDecoder().decode([AllowedApp].self, from: data) {
            allowedApps = decoded
        }
        if let data = defaults.data(forKey: Key.allowedWebsites),
           let decoded = try? JSONDecoder().decode([AllowedWebsite].self, from: data) {
            allowedWebsites = decoded
        }
        let storedDuration = defaults.integer(forKey: Key.selectedDuration)
        selectedDuration = storedDuration == 0 ? 25 : storedDuration
        dewBalance = defaults.integer(forKey: Key.dewBalance)
        notificationEnabled = defaults.object(forKey: Key.notificationEnabled) == nil
            ? true
            : defaults.bool(forKey: Key.notificationEnabled)
        showRemainingTimeInMenuBar = defaults.object(forKey: Key.showRemainingTimeInMenuBar) == nil
            ? true
            : defaults.bool(forKey: Key.showRemainingTimeInMenuBar)
        if let data = defaults.data(forKey: Key.history),
           let decoded = try? JSONDecoder().decode([FocusSessionRecord].self, from: data) {
            history = decoded
        }
        loadProfilesOrMigrateLegacyConfiguration()
    }

    private func restoreActiveSessionIfNeeded() {
        guard let data = defaults.data(forKey: Key.activeSession),
              let active = try? JSONDecoder().decode(PersistedActiveSession.self, from: data) else { return }

        if active.endsAt <= Date() {
            sessionStartedAt = active.startedAt
            currentDurationMinutes = active.durationMinutes
            isSessionActive = true
            completeSession()
            return
        }

        allowedApps = active.allowedApps
        allowedWebsites = active.allowedWebsites ?? []
        sessionStartedAt = active.startedAt
        currentDurationMinutes = active.durationMinutes
        endsAt = active.endsAt
        remainingSeconds = max(1, Int(ceil(active.endsAt.timeIntervalSinceNow)))
        isSessionActive = true
        blocker.start(allowing: allowedApps, websites: allowedWebsites)
        startTicker()
    }

    private func persistAllowedApps(syncProfile: Bool = true) {
        guard let data = try? JSONEncoder().encode(allowedApps) else { return }
        defaults.set(data, forKey: Key.allowedApps)
        if syncProfile { syncSelectedProfile() }
    }

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: Key.history)
    }

    private func persistAllowedWebsites(syncProfile: Bool = true) {
        guard let data = try? JSONEncoder().encode(allowedWebsites) else { return }
        defaults.set(data, forKey: Key.allowedWebsites)
        if syncProfile { syncSelectedProfile() }
    }

    private func loadProfilesOrMigrateLegacyConfiguration() {
        if let data = defaults.data(forKey: Key.profiles),
           let decoded = try? JSONDecoder().decode([FocusProfile].self, from: data),
           !decoded.isEmpty {
            profiles = decoded
            let storedID = defaults.string(forKey: Key.selectedProfileID).flatMap(UUID.init(uuidString:))
            let selected = profiles.first(where: { $0.id == storedID }) ?? profiles[0]
            selectedProfileID = selected.id
            allowedApps = selected.allowedApps
            allowedWebsites = selected.allowedWebsites
            return
        }

        let migrated = FocusProfile(
            name: "日常专注",
            allowedApps: allowedApps,
            allowedWebsites: allowedWebsites
        )
        profiles = [migrated]
        selectedProfileID = migrated.id
        defaults.set(migrated.id.uuidString, forKey: Key.selectedProfileID)
        persistProfiles()
    }

    private func syncSelectedProfile() {
        guard let selectedProfileID,
              let index = profiles.firstIndex(where: { $0.id == selectedProfileID }) else { return }
        profiles[index].allowedApps = allowedApps
        profiles[index].allowedWebsites = allowedWebsites
        persistProfiles()
    }

    private func persistProfiles() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: Key.profiles)
    }

    private func persistActiveSession() {
        guard let startedAt = sessionStartedAt, let endsAt else { return }
        let active = PersistedActiveSession(
            startedAt: startedAt,
            endsAt: endsAt,
            durationMinutes: currentDurationMinutes,
            allowedApps: allowedApps,
            allowedWebsites: allowedWebsites
        )
        guard let data = try? JSONEncoder().encode(active) else { return }
        defaults.set(data, forKey: Key.activeSession)
    }
}
