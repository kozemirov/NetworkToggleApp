import Foundation

// Privileged helper (launch daemon, runs as root).
// Does one thing: turns a network service on/off via networksetup.

final class Helper: NSObject, NSXPCListenerDelegate, HelperProtocol {

    func listener(_ listener: NSXPCListener,
                  shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        connection.exportedObject = self
        connection.resume()
        return true
    }

    func ping(reply: @escaping (String) -> Void) {
        reply("ok, uid=\(getuid())")
    }

    func setServiceEnabled(_ name: String, enabled: Bool,
                           reply: @escaping (Bool, String) -> Void) {
        // Only allow changing services that actually exist.
        let listing = run(["-listallnetworkservices"]).output
        let known = listing.components(separatedBy: "\n").dropFirst()
            .map { $0.hasPrefix("*") ? String($0.dropFirst()) : $0 }
            .filter { !$0.isEmpty }
        guard known.contains(name) else {
            reply(false, "Unknown service: \(name)")
            return
        }

        let r = run(["-setnetworkserviceenabled", name, enabled ? "on" : "off"])
        let text = r.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if r.status == 0 && !text.lowercased().contains("error") {
            reply(true, "")
        } else {
            reply(false, text.isEmpty ? "networksetup exited with code \(r.status)" : text)
        }
    }

    private func run(_ args: [String]) -> (status: Int32, output: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch { return (-1, "\(error)") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}

let helper = Helper()
let listener = NSXPCListener(machServiceName: Shared.helperMachService)
// Accept connections only from programs signed by our team.
listener.setConnectionCodeSigningRequirement(
    "anchor apple generic and certificate leaf[subject.OU] = \"\(Shared.teamID)\""
)
listener.delegate = helper
listener.resume()
RunLoop.main.run()
