import ServiceManagement
import SwiftUI

@main
struct NetworkToggleApp: App {
    @StateObject private var vm = NetworkToggleViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent().environmentObject(vm)
        } label: {
            Image(systemName: "network")
        }
        .menuBarExtraStyle(.menu)

        Window("About", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
    }
}

struct MenuContent: View {
    @EnvironmentObject var vm: NetworkToggleViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("Network Services:")
        if vm.services.isEmpty {
            Text("No services")
        }
        ForEach(vm.services) { s in
            Toggle(isOn: Binding(get: { s.enabled }, set: { vm.setEnabled(s, $0) })) {
                rowLabel(for: s)
            }
            .disabled(vm.pendingServices.contains(s.name))
        }

        if vm.helperStatus != .enabled {
            Divider()
            Button(vm.helperStatus == .requiresApproval ? "Open Settings… (required)" :
                    "Install Helper… (required)"){
                vm.registerHelper()
            }
            if let e = vm.errorMessage {
                Text(e).foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }
        }

        Divider()
        Toggle("Launch at Login", isOn: Binding(get: { vm.launchAtLogin },
                                                set: { vm.setLaunchAtLogin($0) }))
        Button("About") {
            openWindow(id: "about")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("Quit") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    /// One `Text` with the name and a dimmed status suffix from `NetService.status.title`.
    private func rowLabel(for s: NetService) -> Text {
        var name = AttributedString(s.name)
        var status = AttributedString(" [\(s.status.title)]")
        status.foregroundColor = Color(nsColor: .tertiaryLabelColor)
        name += status
        return Text(name)
    }
}
