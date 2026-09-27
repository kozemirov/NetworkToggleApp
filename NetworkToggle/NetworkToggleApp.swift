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

    /// A single `Text` (built from an `AttributedString`) with the service name
    /// in the normal color and the status suffix dimmed. Menu-bar items only
    /// render a single `Text` correctly — a layout container like `HStack`
    /// doesn't show up in a `MenuBarExtra`'s `.menu` style — so this replaces
    /// the deprecated `Text + Text` concatenation without losing the two-tone
    /// color.
    ///
    /// The status text itself comes from `NetService.status.title`, the same
    /// property the Control Center control reads, so both surfaces always
    /// agree on the same service's state. While a toggle is in flight the row
    /// is just disabled (see above) rather than getting a separate "Updating…"
    /// label — one less status variant to keep in sync.
    private func rowLabel(for s: NetService) -> Text {
        var name = AttributedString(s.name)
        var status = AttributedString(" [\(s.status.title)]")
        status.foregroundColor = Color(nsColor: .tertiaryLabelColor)
        name += status
        return Text(name)
    }
}
