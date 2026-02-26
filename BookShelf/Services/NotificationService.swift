import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Daily Reminder

    func scheduleDailyReminder(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Time to Read"
        content.body = "A few pages a day keeps the streak alive!"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyReadingReminder", content: content, trigger: trigger)

        center.add(request)
    }

    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["dailyReadingReminder"])
    }

    // MARK: - Streak Protection

    func scheduleStreakReminderIfNeeded(currentStreak: Int, hasReadToday: Bool) {
        center.removePendingNotificationRequests(withIdentifiers: ["streakProtection"])

        guard currentStreak > 0, !hasReadToday else { return }

        let content = UNMutableNotificationContent()
        content.title = "Protect Your Streak!"
        content.body = "You have a \(currentStreak)-day reading streak. Read a few pages to keep it going!"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 21
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "streakProtection", content: content, trigger: trigger)

        center.add(request)
    }

    func cancelStreakReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["streakProtection"])
    }
}
