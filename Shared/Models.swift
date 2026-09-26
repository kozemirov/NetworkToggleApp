import Foundation

enum ServiceState: String, Codable, Sendable {
    case working      // enabled, interface active, has an IP
    case notWorking   // enabled, but no link or no IP
    case disabled     // disabled in network settings

    var title: String {
        switch self {
        case .working: return "Active"
        case .notWorking: return "Not Working"
        case .disabled: return "Inactive"
        }
    }
}

struct NetService: Identifiable, Codable, Equatable, Sendable {
    var id: String { name }
    var order: Int
    var name: String
    var port: String
    var device: String
    var enabled: Bool

    var state: ServiceState = .notWorking
    var linkStatus: String = "—"
    var ip: String = "—"
    var subnet: String = "—"
    var router: String = "—"
    var config: String = "—"
    var ipv6: String = "—"
    var mac: String = "—"
    var dns: String = "—"
    var searchDomains: String = "—"
    var mtu: String = "—"
    var media: String = "—"

    /// Set right after the service is turned on; while this is in the future,
    /// the UI shows "Connecting…" instead of a possibly-stale "Not Working"
    /// (the interface can take a few seconds to get a link and an IP).
    var connectingUntil: Date? = nil
}
