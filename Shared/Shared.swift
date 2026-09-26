import Foundation

// Shared constants, App Group data exchange, and the XPC client.
// This file is part of all three targets: app, widget, and helper.

enum Shared {
    static let appGroup = "group.com.pavelkozemirov.NetworkToggle"
    static let helperMachService = "app.pavelkozemirov.NetworkToggle.helper"
    static let helperPlistName = "app.pavelkozemirov.NetworkToggle.helper.plist"
    static let controlKind = "app.pavelkozemirov.NetworkToggle.ServiceControl"
    static let teamID = "T7VDL5R876"

    /// How long after enabling a service we still show "Connecting…" before
    /// trusting a "Not Working" reading (interfaces can take a few seconds to
    /// get a link and an IP after being turned on).
    static let connectingGracePeriod: TimeInterval = 8
}

// MARK: - State snapshot in the App Group (app writes, widget reads)

enum SnapshotStore {
    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Shared.appGroup)?
            .appendingPathComponent("services.json")
    }

    static func load() -> [NetService] {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([NetService].self, from: data)
        else { return [] }
        return list
    }

    static func save(_ list: [NetService]) {
        guard let url = fileURL, let data = try? JSONEncoder().encode(list) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Reflect a toggle right away, without waiting for the app's next poll.
    static func patchEnabled(name: String, enabled: Bool) {
        var list = load()
        guard let i = list.firstIndex(where: { $0.name == name }) else { return }
        list[i].enabled = enabled
        if enabled {
            list[i].connectingUntil = Date().addingTimeInterval(Shared.connectingGracePeriod)
        } else {
            // Only the app determines the real status (working / not working),
            // so we don't guess it here; when disabling, the status is unambiguous.
            list[i].state = .disabled
            list[i].connectingUntil = nil
        }
        save(list)
    }
}

// MARK: - XPC

@objc(NetworkToggleHelperProtocol)
protocol HelperProtocol {
    func ping(reply: @escaping (String) -> Void)
    func setServiceEnabled(_ name: String, enabled: Bool, reply: @escaping (Bool, String) -> Void)
}

enum HelperError: LocalizedError {
    case failed(String)
    var errorDescription: String? {
        switch self { case .failed(let m): return m }
    }
}

private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func claim() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}

enum HelperClient {
    static func setEnabled(_ name: String, enabled: Bool) async throws {
        let conn = NSXPCConnection(machServiceName: Shared.helperMachService, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        conn.resume()
        defer { conn.invalidate() }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let once = ResumeOnce()
            let proxy = conn.remoteObjectProxyWithErrorHandler { error in
                if once.claim() { cont.resume(throwing: error) }
            } as? HelperProtocol

            guard let proxy else {
                if once.claim() { cont.resume(throwing: HelperError.failed("No connection to the helper")) }
                return
            }
            proxy.setServiceEnabled(name, enabled: enabled) { ok, message in
                guard once.claim() else { return }
                if ok { cont.resume() } else { cont.resume(throwing: HelperError.failed(message)) }
            }
        }
    }
}
