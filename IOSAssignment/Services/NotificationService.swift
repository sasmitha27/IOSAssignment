import Foundation
import UserNotifications

struct NotificationService {
    static let dailyChallengeIdentifier = "dailyChallenge"

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func scheduleDailyChallenge(at date: Date) async throws {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyChallengeIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Daily Challenge"
        content.body = "Play a quick round and beat yesterday's score."
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.dailyChallengeIdentifier,
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    func cancelDailyChallenge() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.dailyChallengeIdentifier])
    }
}
