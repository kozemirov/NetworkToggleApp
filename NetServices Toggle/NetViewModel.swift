import Combine
import Foundation
import ServiceManagement
import WidgetKit

@MainActor
final class NetViewModel: ObservableObject {
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
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.refresh()
            }
        }
    }

    var workingCount: Int { services.filter { $0.state == .working }.count }

    func refresh() {
        Task { await refreshAsync() }
    }

    /// Same as `refresh()`, but awaitable so callers (like `setEnabled`) can wait
    /// for the status to actually be up to date before clearing "loading…".
    @discardableResult
    func refreshAsync() async -> Bool {
        helperStatus = helper.status
        // Pick up changes made outside the app (e.g. in System Settings → Login Items).
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if loading { return false }
        loading = true
        let collected = await Task.detached(priority: .userInitiated) {
            NetCollector.collect()
        }.value

        // The collector has no notion of "just enabled" — preserve each
        // service's "still connecting" marker from the on-disk snapshot until
        // it actually expires, otherwise a fresh poll could report
        // "Not Working" for a moment before the interface's link/IP come up.
        let onDisk = SnapshotStore.load()
        let onDiskByName = Dictionary(uniqueKeysWithValues: onDisk.map { ($0.name, $0) })
        let result = collected.map { service -> NetService in
            var service = service
            if let until = onDiskByName[service.name]?.connectingUntil, until > Date() {
                service.connectingUntil = until
            }
            return service
        }

        // Also compare against the App Group file: the widget may have changed it,
        // and then the Control needs to redraw even if nothing changed in memory.
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
                // Mark it as "connecting" right away, same as the Control does,
                // so all surfaces agree while the interface comes up.
                SnapshotStore.patchEnabled(name: service.name, enabled: on)
                errorMessage = nil
            } catch {
                errorMessage = "Couldn't toggle \"\(service.name)\": \(error.localizedDescription)"
            }
            try? await Task.sleep(for: .seconds(1))
            // Keep polling briefly until a refresh actually runs (skips ones that
            // find the view model already mid-refresh) so "loading…" doesn't
            // disappear before the real status has caught up.
            while await refreshAsync() == false {
                try? await Task.sleep(for: .milliseconds(300))
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
