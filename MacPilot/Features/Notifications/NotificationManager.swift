import UserNotifications

/// Actor wrapping `UNUserNotificationCenter` for authorization and delivery.
///
/// Follows the singleton pattern used by `ClaudeCLI` to serialize
/// notification operations through a single actor instance.
actor NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Authorization

    /// Checks the current authorization status and requests permission if not yet determined.
    ///
    /// - Returns: `true` if notifications are authorized, `false` if denied or restricted.
    func ensureAuthorized() async throws -> Bool {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            return try await center.requestAuthorization(options: [.alert, .sound])
        case .denied, .ephemeral:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Delivery

    /// Sends a local notification with the given title and body.
    ///
    /// - Parameters:
    ///   - title: The notification title.
    ///   - body: The notification body text.
    /// - Returns: A confirmation message, or guidance if permission was denied.
    func send(title: String, body: String) async throws -> String {
        let authorized = try await ensureAuthorized()

        guard authorized else {
            return "Notification permission denied. Please enable notifications for MacPilot in System Settings > Notifications."
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try await center.add(request)
        return "Notification sent."
    }
}
