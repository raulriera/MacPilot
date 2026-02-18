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
            MenuBarContent(launchAtLogin: $launchAtLogin)
        }
        .modelContainer(modelContainer)

        Window("Getting Started", id: "getting-started") {
            GettingStartedView()
        }
        .modelContainer(modelContainer)

        Window("Activity Log", id: "activity-log") {
            ActivityLogView()
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

private struct MenuBarContent: View {
    @Binding var launchAtLogin: Bool
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Getting Started\u{2026}") {
            openWindow(id: "getting-started")
        }

        Button("Activity Log\u{2026}") {
            openWindow(id: "activity-log")
        }

        Divider()

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
