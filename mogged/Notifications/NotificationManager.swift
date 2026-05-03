import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let oneDayID = "reengagement-1d"
    private let oneWeekID = "reengagement-7d"

    func requestPermissionIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func scheduleReengagement() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        center.removePendingNotificationRequests(withIdentifiers: [oneDayID, oneWeekID])

        try? await center.add(makeNotification(
            id: oneDayID,
            title: "How are you looking today?",
            body: "Drop back in and check your score.",
            after: 86_400
        ))
        try? await center.add(makeNotification(
            id: oneWeekID,
            title: "It's been a week.",
            body: "See if your rating has changed.",
            after: 604_800
        ))
    }

    private func makeNotification(id: String, title: String, body: String, after seconds: TimeInterval) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }
}
