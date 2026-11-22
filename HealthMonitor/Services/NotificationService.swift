import Foundation
import UserNotifications

/// Sends local notifications only. No push, no server, nothing leaves
/// the phone. Used only for real alerts, never for watch notes.
final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    /// Asks for permission to show alerts. Called once, after HealthKit
    /// access is granted, so the user is not hit with two system prompts
    /// at the same moment.
    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Delivers an alert immediately. Best effort: a failure to deliver
    /// never affects the in-app record.
    func sendAlert(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "healthmonitor.alert.\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Best effort only.
        }
    }
}
