import AppIntents
import SwiftUI
import WidgetKit

struct NetworkToggleAppControl: ControlWidget {
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
                  status: ServiceStatus.activeConnected.title, symbol: "network")
        }

        func currentValue(configuration: ServiceConfiguration) async throws -> Value {
            // One call refreshes `enabled` and connectivity straight from the
            // OS, so the control is correct even if the app isn't running to
            // keep its snapshot current (and even if it has never run once).
            guard let id = configuration.service?.id,
                  var s = liveService(named: id) else {
                return Value(name: "Choose a service", isOn: false,
                             status: "Not configured", symbol: "network.slash")
            }
            // `connectingUntil` is our own bookkeeping, not an OS fact, so it
            // can only come from the snapshot — written the moment anyone
            // (app or Control) toggles the service, so it doesn't go stale.
            s.connectingUntil = SnapshotStore.load().first(where: { $0.name == id })?.connectingUntil

            // The icon depends only on whether the service is enabled; the
            // status text uses the same `status.title` the menu bar shows, so
            // the same service never reads differently in the two places.
            let symbol = s.enabled ? "network" : "network.slash"
            return Value(name: s.name, isOn: s.enabled, status: s.status.title, symbol: symbol)
        }
    }
}
