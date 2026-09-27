import Foundation

// Shared constants, App Group data exchange, and the XPC client (used by all three targets).

func runTool(_ path: String, _ args: [String]) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: path)
    p.arguments = args
    var env = ProcessInfo.processInfo.environment
    env["LANG"] = "en_US.UTF-8"
    p.environment = env
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe
    do { try p.run() } catch { return "" }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return String(decoding: data, as: UTF8.self)
}

func networksetup(_ args: [String]) -> String {
    runTool("/usr/sbin/networksetup", args)
}

/// Parses `networksetup -listnetworkserviceorder` into services (order/name/device/enabled).
func parseServiceOrder(_ text: String) -> [NetService] {
    var result: [NetService] = []
    let lines = text.components(separatedBy: "\n")
    var i = 0
    while i < lines.count {
        let line = lines[i].trimmingCharacters(in: .whitespaces)
        if line.hasPrefix("("), !line.hasPrefix("(Hardware"),
           let close = line.range(of: ") ") {
            let marker = String(line[line.index(after: line.startIndex)..<close.lowerBound])
            let name = String(line[close.upperBound...])
            let enabled = marker != "*"
            var device = ""
            if i + 1 < lines.count {
                let next = lines[i + 1].trimmingCharacters(in: .whitespaces)
                if next.hasPrefix("(Hardware Port:") {
                    let body = String(next.dropFirst().dropLast())
                    if let dev = body.range(of: ", Device:") {
                        device = String(body[dev.upperBound...])
                            .trimmingCharacters(in: .whitespaces)
                    }
                    i += 1
                }
            }
            result.append(NetService(order: result.count + 1, name: name,
                                     device: device, enabled: enabled))
        }
        i += 1
    }
    return result
}

/// Active link + a real (non-APIPA) IPv4 address for one device, via a single `ifconfig` call.
func hasLinkAndIP(device: String) -> Bool {
    guard !device.isEmpty else { return false }
    let ifc = runTool("/sbin/ifconfig", [device])

    var active = false
    if let r = ifc.range(of: "status: ") {
        active = String(ifc[r.upperBound...].components(separatedBy: "\n")[0]) == "active"
    } else if ifc.contains("UP") {
        active = true
    }

    var ip = "—"
    for line in ifc.components(separatedBy: "\n") {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("inet "), !t.hasPrefix("inet6") {
            let parts = t.split(separator: " ")
            if parts.count > 1 { ip = String(parts[1]) }
            break
        }
    }
    return ip != "—" && !ip.hasPrefix("169.254") && active
}

/// Refreshes everything the OS knows about one named service — `enabled` and connectivity — in one call.
func liveService(named name: String) -> NetService? {
    guard var service = parseServiceOrder(networksetup(["-listnetworkserviceorder"]))
        .first(where: { $0.name == name }) else { return nil }
    service.hasLinkAndIP = hasLinkAndIP(device: service.device)
    return service
}

enum Shared {
    static let appGroup = "group.app.pavelkozemirov.NetworkToggle"
    static let helperMachService = "app.pavelkozemirov.NetworkToggle.helper"
    static let helperPlistName = "app.pavelkozemirov.NetworkToggle.helper.plist"
    static let controlKind = "app.pavelkozemirov.NetworkToggle.ServiceControl"
    static let teamID = "T7VDL5R876"
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

    /// Reflects a toggle right away; builds a fresh entry via `liveService` if the snapshot doesn't have it yet.
    static func patchEnabled(name: String, enabled: Bool) {
        var list = load()
        let connectingUntil = enabled ? Date().addingTimeInterval(NetService.connectingGracePeriod) : nil

        if let i = list.firstIndex(where: { $0.name == name }) {
            list[i].enabled = enabled
            // `status` already reports `.inactive` once `enabled` is false.
            list[i].connectingUntil = connectingUntil
        } else if var service = liveService(named: name) {
            service.enabled = enabled
            service.connectingUntil = connectingUntil
            list.append(service)
        } else {
            return // no such service — nothing to patch
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
