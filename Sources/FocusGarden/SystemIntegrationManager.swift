import AppKit
import ServiceManagement

@MainActor
final class SystemIntegrationManager: ObservableObject {
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var guardianEnabled = false
    @Published private(set) var statusMessage: String?

    private let mainAppService = SMAppService.mainApp
    private let guardianService = SMAppService.loginItem(identifier: "dev.local.focusgarden.guardian")

    init() {
        refresh()
    }

    func refresh() {
        launchAtLoginEnabled = mainAppService.status == .enabled || mainAppService.status == .requiresApproval
        guardianEnabled = guardianService.status == .enabled || guardianService.status == .requiresApproval

        if mainAppService.status == .requiresApproval || guardianService.status == .requiresApproval {
            statusMessage = "登录项已添加，仍需在系统设置中批准。"
        } else {
            statusMessage = nil
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        let errorMessage = update(service: mainAppService, enabled: enabled, label: "登录时启动")
        refresh()
        if let errorMessage { statusMessage = errorMessage }
    }

    func setGuardianEnabled(_ enabled: Bool) {
        let errorMessage = update(service: guardianService, enabled: enabled, label: "后台守护")
        refresh()
        if let errorMessage { statusMessage = errorMessage }
    }

    func openLoginItemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    private func update(service: SMAppService, enabled: Bool, label: String) -> String? {
        do {
            if enabled {
                if service.status == .notRegistered || service.status == .notFound {
                    try service.register()
                }
            } else if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            }
            return nil
        } catch {
            return "\(label)设置失败：\(error.localizedDescription)"
        }
    }
}
