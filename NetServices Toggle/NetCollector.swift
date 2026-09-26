import Foundation

// Data collection via networksetup / ifconfig (works without sandbox).

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

enum NetCollector {
    static func collect() -> [NetService] {
        var services = parseOrder(networksetup(["-listnetworkserviceorder"]))
        for i in services.indices { enrich(&services[i]) }
        return services
    }

    /// (1) Wi-Fi
    /// (Hardware Port: Wi-Fi, Device: en0)
    static func parseOrder(_ text: String) -> [NetService] {
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
                var port = "", device = ""
                if i + 1 < lines.count {
                    let next = lines[i + 1].trimmingCharacters(in: .whitespaces)
                    if next.hasPrefix("(Hardware Port:") {
                        let body = String(next.dropFirst().dropLast())
                        if let dev = body.range(of: ", Device:") {
                            port = String(body[body.startIndex..<dev.lowerBound])
                                .replacingOccurrences(of: "Hardware Port:", with: "")
                                .trimmingCharacters(in: .whitespaces)
                            device = String(body[dev.upperBound...])
                                .trimmingCharacters(in: .whitespaces)
                        }
                        i += 1
                    }
                }
                result.append(NetService(order: result.count + 1, name: name,
                                         port: port, device: device, enabled: enabled))
            }
            i += 1
        }
        return result
    }

    static func keyValues(_ text: String) -> [String: String] {
        var d: [String: String] = [:]
        for line in text.components(separatedBy: "\n") {
            guard let r = line.range(of: ": ") else { continue }
            let k = String(line[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
            let v = String(line[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            if d[k] == nil { d[k] = v }
        }
        return d
    }

    static func listOrDash(_ text: String) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty || t.contains("aren't any") { return "—" }
        return t.components(separatedBy: "\n").joined(separator: ", ")
    }

    static func enrich(_ s: inout NetService) {
        let info = keyValues(networksetup(["-getinfo", s.name]))
        func val(_ k: String) -> String {
            guard let v = info[k], !v.isEmpty, v.lowercased() != "none" else { return "—" }
            return v
        }
        if let cfg = info.keys.first(where: { $0.hasSuffix("Configuration") }) {
            s.config = cfg.replacingOccurrences(of: " Configuration", with: "")
        }
        s.ip = val("IP address")
        s.subnet = val("Subnet mask")
        s.router = val("Router")
        s.ipv6 = val("IPv6 IP address")
        s.mac = val("Ethernet Address")
        s.dns = listOrDash(networksetup(["-getdnsservers", s.name]))
        s.searchDomains = listOrDash(networksetup(["-getsearchdomains", s.name]))

        var active = false
        if !s.device.isEmpty {
            let mtu = networksetup(["-getMTU", s.device])
            if let r = mtu.range(of: "MTU value is ") {
                let digits = String(mtu[r.upperBound...].prefix(while: { $0.isNumber }))
                if !digits.isEmpty { s.mtu = digits }
            }
            let media = networksetup(["-getMedia", s.device])
            if let r = media.range(of: "Active: ") {
                s.media = String(media[r.upperBound...].components(separatedBy: "\n")[0])
                    .trimmingCharacters(in: .whitespaces)
            }
            let ifc = runTool("/sbin/ifconfig", [s.device])
            if let r = ifc.range(of: "status: ") {
                s.linkStatus = String(ifc[r.upperBound...].components(separatedBy: "\n")[0])
                active = s.linkStatus == "active"
            } else if ifc.contains("UP") {
                s.linkStatus = "up"
                active = true
            }
            if s.ip == "—" {
                for line in ifc.components(separatedBy: "\n") {
                    let t = line.trimmingCharacters(in: .whitespaces)
                    if t.hasPrefix("inet "), !t.hasPrefix("inet6") {
                        let parts = t.split(separator: " ")
                        if parts.count > 1 { s.ip = String(parts[1]) }
                        break
                    }
                }
            }
        }

        let hasIP = s.ip != "—" && !s.ip.hasPrefix("169.254")
        if !s.enabled { s.state = .disabled }
        else { s.state = (active && hasIP) ? .working : .notWorking }
    }
}
