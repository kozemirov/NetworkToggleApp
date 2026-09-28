import Combine
import Foundation
import ServiceManagement
import WidgetKit

@MainActor
final class NetworkToggleViewModel: ObservableObject {
    @Published var services: [NetService] = []
    @Published var lastUpdate: Date?
    @Published var loading = false
    @Published var helperStatus: SMAppService.Status = .notRegistered
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @Published var errorMessage: String?
    /// Names of services currently being turned on/off, waiting for the status to catch up.
    @Published var pendingServices: Set<String> = []

    private var timer: Timer?
    private let helper = SMAppService.daemon(plistName: Shared.helperPlistName)

    init() {
        helperStatus = helper.status
        // Ask for the helper right away if it isn't approved yet.
        if helperStatus != .enabled {
            registerHelper()
        }
        refresh()
        let t = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func refresh() {
        Task { await refreshAsync() }
    }

    /// Awaitable version of `refresh()`, so callers can wait for the status to catch up.
    @discardableResult
    func refreshAsync() async -> Bool {
        helperStatus = helper.status
        // Pick up changes made outside the app (e.g. in System Settings → Login Items).
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if loading { return false }
        loading = true
        let collected = await Task.detached(priority: .userInitiated) {
            NetworkToggleServiceCollector.collect()
        }.value

        // Preserve each service's "still connecting" marker until it actually expires.
        let onDisk = SnapshotStore.load()
        let onDiskByName = Dictionary(uniqueKeysWithValues: onDisk.map { ($0.name, $0) })
        let result = collected.map { service -> NetService in
            var service = service
            if let until = onDiskByName[service.name]?.connectingUntil, until > Date() {
                service.connectingUntil = until
            }
            return service
        }

        // Also compare against the App Group file, since the widget may have changed it.
        if result != self.services || result != onDisk {
            self.services = result
            SnapshotStore.save(result)
            ControlCenter.shared.reloadControls(ofKind: Shared.controlKind)
        }
        self.lastUpdate = Date()
        self.loading = false
        return true
    }

    func setEnabled(_ service: NetService, _ on: Bool) {
        pendingServices.insert(service.name)
        Task {
            do {
                try await HelperClient.setEnabled(service.name, enabled: on)
                // Mark it as "connecting" right away, same as the Control does.
                SnapshotStore.patchEnabled(name: service.name, enabled: on)
                errorMessage = nil
            } catch {
                errorMessage = "Couldn't toggle \"\(service.name)\": \(error.localizedDescription)"
            }
            try? await Task.sleep(for: .seconds(1))
            // Poll every second until status resolves or the grace period ends.
            for _ in 0..<Int(NetService.connectingGracePeriod) {
                await refreshAsync()
                if let s = services.first(where: { $0.name == service.name }),
                   s.status != .activeConnecting { break }
                try? await Task.sleep(for: .seconds(1))
            }
            pendingServices.remove(service.name)
        }
    }

    func registerHelper() {
        do {
            try helper.register()
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't register the helper: \(error.localizedDescription)"
        }
        helperStatus = helper.status
        if helperStatus == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't change Launch at Login: \(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
