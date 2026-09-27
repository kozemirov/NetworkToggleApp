import Foundation

// Data collection via networksetup / ifconfig (works without sandbox).
// `runTool`, `parseServiceOrder` and the live connectivity check live in
// Shared.swift so the Control Center extension can reuse them too — see
// `liveService(named:)`.

enum NetworkServiceCollector {
    static func collect() -> [NetService] {
        var services = parseServiceOrder(networksetup(["-listnetworkserviceorder"]))
        for i in services.indices {
            services[i].hasLinkAndIP = hasLinkAndIP(device: services[i].device)
        }
        return services
    }
}
