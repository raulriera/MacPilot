import SwiftUI
import SwiftData
import ServiceManagement

@main
struct MacPilotApp: App {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: Session.self, ToolExecutionLog.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        SessionManager.shared.configure(with: modelContainer)
        ToolExecutionLogger.shared.configure(with: modelContainer)
    }

    var body: some Scene {
        MenuBarExtra("MacPilot", systemImage: "brain") {
            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    setLaunchAtLogin(newValue)
                }

            Divider()

            Button("Quit MacPilot") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .modelContainer(modelContainer)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
