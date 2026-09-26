# Network Toggle

A macOS app that lists network services (from `networksetup -listnetworkserviceorder`), shows their status, and lets you turn them on/off from the menu bar and a Control Center. This is especially handy if you often switch between a wired Ethernet connection, a Wi-Fi network, a Personal Hotspot connection or phone USB connection.

## Status logic (Active / Not Working / Inactive)

For each service, checked in this order:

1. **Inactive** — the service is Active in Network settings (`networksetup -setnetworkserviceenabled`). No further checks
2. **Link check** — `ifconfig <device>` must report `status: active` (or be `UP` with no `status` field, e.g. VPN interfaces).
3. **IP check** — the service must have a real IPv4 address (not empty, not a `169.254.x.x` self-assigned APIPA address).
4. **Active** if enabled + active link + real IP. Otherwise **Not Working**.

This only confirms local link + IP (L2/L3), not actual internet reachability — a service connected to a network with no internet access will still show as Working.

## Privileged helper

Reading a service's status needs no special privileges, but actually turning one on or off (`networksetup -setnetworkserviceenabled`) does — it requires root. Since the app itself runs unprivileged, it installs a small privileged helper (a `launchd` daemon registered via `SMAppService.daemon`) whose only job is to run that one command over XPC, after checking that the request came from a process signed with the same Team ID.

Because the helper runs as root, macOS requires the user to explicitly approve it in System Settings → General → Login Items & Extensions — the app cannot register it silently, this confirmation step can't be skipped. The app requests approval automatically on launch whenever it isn't granted yet; if the prompt is missed or dismissed, the same request can be repeated from the menu ("Install Helper…" / "Open Settings…"). Until approved, everything except toggling still works — the service list and their statuses are read without the helper.
