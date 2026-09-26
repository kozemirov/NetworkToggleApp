import ServiceManagement
import SwiftUI

@main
struct NetworkToggleApp: App {
    @StateObject private var vm = NetworkToggleViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuContent().environmentObject(vm)
        } label: {
            Image(systemName: vm.workingCount > 0 ? "network" : "network.slash")
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
        }

        if vm.helperStatus != .enabled {
            Divider()
            Button(vm.helperStatus == .requiresApproval ? "Open Settings…" : "Install Helper…") {
                vm.registerHelper()
            }
        }

        if let e = vm.errorMessage {
            Divider()
            Text(e).foregroundColor(Color(nsColor: .tertiaryLabelColor))
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

    private func statusText(_ s: NetService) -> String {
        if vm.pendingServices.contains(s.name) { return "Updating…" }
        switch s.state {
        case .working: return "Connected"
        case .notWorking: return "Not connected"
        case .disabled: return "Disabled"
        }
    }

    /// A single `Text` (built from an `AttributedString`) with the service name
    /// in the normal color and the status suffix dimmed. Menu-bar items only
    /// render a single `Text` correctly — a layout container like `HStack`
    /// doesn't show up in a `MenuBarExtra`'s `.menu` style — so this replaces
    /// the deprecated `Text + Text` concatenation without losing the two-tone
    /// color.
    private func rowLabel(for s: NetService) -> Text {
        var name = AttributedString(s.name)
        var status = AttributedString(" [\(statusText(s))]")
        status.foregroundColor = Color(nsColor: .tertiaryLabelColor)
        name += status
        return Text(name)
    }
}
