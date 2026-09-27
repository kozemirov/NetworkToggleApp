import Foundation

// Data collection via networksetup / ifconfig; shared helpers live in Shared.swift.

enum NetworkToggleServiceCollector {
    static func collect() -> [NetService] {
        var services = parseServiceOrder(networksetup(["-listnetworkserviceorder"]))
        for i in services.indices {
            services[i].hasLinkAndIP = hasLinkAndIP(device: services[i].device)
        }
        return services
    }
}
