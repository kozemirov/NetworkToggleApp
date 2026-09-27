import Foundation

/// The status a network service shows to the user, everywhere in the app.
/// This is the single source of truth for that text — both the menu bar and
/// the Control Center control read `NetService.status` / `.title`, never
/// their own separate logic, so the same service can't read differently in
/// the two places.
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
    /// How long after enabling a service it stays `.activeConnecting` before
    /// a missing link/IP is trusted as a real `.activeNotConnected`.
    static let connectingGracePeriod: TimeInterval = 8

    var id: String { name }
    var order: Int
    var name: String
    var device: String
    var enabled: Bool

    /// The raw connectivity check (active link + a real, non-APIPA IP) — the
    /// only network fact besides `enabled` that `status` needs.
    var hasLinkAndIP: Bool = false

    /// Set right after the service is turned on; while this is in the future,
    /// `status` reports `.activeConnecting` instead of a possibly-stale
    /// `.activeNotConnected` (the interface can take a few seconds to get a
    /// link and an IP).
    var connectingUntil: Date? = nil

    /// The single computed status — see `ServiceStatus`. Everything that
    /// needs to show or reason about a service's state goes through this,
    /// never through `enabled` / `hasLinkAndIP` / `connectingUntil` directly.
    var status: ServiceStatus {
        guard enabled else { return .inactive }
        if let until = connectingUntil, until > Date() { return .activeConnecting }
        return hasLinkAndIP ? .activeConnected : .activeNotConnected
    }
}
