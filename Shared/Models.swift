import Foundation

/// The status shown everywhere in the app — the single source of truth for that text.
enum ServiceStatus {
    case inactive            // disabled in Network settings
    case activeConnecting    // just enabled; giving the interface a moment to get a link + IP
    case activeNotConnected  // enabled, but no link or no IP (and not just-enabled anymore)
    case activeConnected     // enabled, active link, real IP

    var title: String {
        switch self {
        case .inactive: return "Inactive"
        case .activeConnecting: return "Connecting…"
        case .activeNotConnected: return "Not Connected"
        case .activeConnected: return "Connected"
        }
    }
}

struct NetService: Identifiable, Codable, Equatable, Sendable {
    /// How long a service stays `.activeConnecting` before a missing link/IP counts as real.
    static let connectingGracePeriod: TimeInterval = 8

    var id: String { name }
    var order: Int
    var name: String
    var device: String
    var enabled: Bool

    /// The raw connectivity check (active link + a real, non-APIPA IP).
    var hasLinkAndIP: Bool = false

    /// Set right after enabling; while in the future, `status` reports `.activeConnecting`.
    var connectingUntil: Date? = nil

    /// The single computed status everything should read instead of the raw fields.
    var status: ServiceStatus {
        guard enabled else { return .inactive }
        if let until = connectingUntil, until > Date() { return .activeConnecting }
        return hasLinkAndIP ? .activeConnected : .activeNotConnected
    }
}
