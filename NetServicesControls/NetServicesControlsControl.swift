import AppIntents
import SwiftUI
import WidgetKit

struct NetServicesControlsControl: ControlWidget {
    struct Value {
        var name: String
        var isOn: Bool
        var status: String
        var symbol: String
    }

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Shared.controlKind,
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                value.name,
                isOn: value.isOn,
                action: ToggleServiceIntent(service: ServiceEntity(id: value.name))
            ) { _ in
                Label(value.status, systemImage: value.symbol)
            }
        }
        .displayName("Network Service")
        .description("Shows a network service's status and turns it on or off.")
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: ServiceConfiguration) -> Value {
            Value(name: configuration.service?.id ?? "Wi-Fi", isOn: true,
                  status: "Working", symbol: "network")
        }

        func currentValue(configuration: ServiceConfiguration) async throws -> Value {
            let list = SnapshotStore.load()
            guard let id = configuration.service?.id,
                  let s = list.first(where: { $0.name == id }) else {
                return Value(name: "Choose a service", isOn: false,
                             status: "Not configured", symbol: "network.slash")
            }
            // The icon depends only on whether the service is enabled;
            // whether it's actually working shows up in the status text.
            var status = s.state.title
            if s.state != .working, let until = s.connectingUntil, until > Date() {
                // Just enabled — give the interface a few seconds to get a
                // link and an IP before reporting "Not Working".
                status = "Connecting…"
            }
            let symbol = s.enabled ? "network" : "network.slash"
            return Value(name: s.name, isOn: s.enabled, status: status, symbol: symbol)
        }
    }
}
