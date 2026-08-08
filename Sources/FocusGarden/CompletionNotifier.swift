import Foundation
import UserNotifications

@MainActor
final class CompletionNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = CompletionNotifier()

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization() {
        Task { @MainActor in
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .notDetermined else { return }
            _ = try? await center.requestAuthorization(options: [.alert, .badge])
        }
    }

    func sendCompletion(plant: PlantKind, minutes: Int, reward: Int) {
        let content = UNMutableNotificationContent()
        content.title = "\(plant.name)长成了"
        content.body = "完成 \(minutes) 分钟专注，获得 \(reward) 露珠。"
        content.categoryIdentifier = "FOCUS_COMPLETE"
        content.sound = nil

        center.add(UNNotificationRequest(
            identifier: "focus-complete-\(UUID().uuidString)",
            content: content,
            trigger: nil
        ))
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }
}
