import AppIntents

struct SendNotificationIntent: AppIntent {
    static let title: LocalizedStringResource = "Send Notification"
    static let description: IntentDescription = "Send a macOS notification with a custom title and body."

    static let openAppWhenRun: Bool = false

    @Parameter(title: "Title")
    var notificationTitle: String

    @Parameter(title: "Body")
    var body: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = try await NotificationManager.shared.send(
            title: notificationTitle,
            body: body
        )
        return .result(value: result)
    }
}
