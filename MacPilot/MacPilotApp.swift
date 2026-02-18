import SwiftUI
import ServiceManagement

@main
struct MacPilotApp: App {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

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
