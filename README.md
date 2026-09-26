# Network Toggle

_(The Xcode project and target names are still `NetServices Toggle` internally; the app displays as "Network Toggle" everywhere via `CFBundleDisplayName`.)_

A macOS app that lists network services (from `networksetup -listnetworkserviceorder`), shows their status, and lets you turn them on/off from the menu bar and a Control Center. This is especially handy if you often switch between a wired Ethernet connection, a Wi-Fi network, a Personal Hotspot connection or phone USB connection.

## Status logic (Active / Not Working / Inactive)

For each service, checked in this order:

1. **Inactive** — the service is Active in Network settings (`networksetup -setnetworkserviceenabled`). No further checks
2. **Link check** — `ifconfig <device>` must report `status: active` (or be `UP` with no `status` field, e.g. VPN interfaces).
3. **IP check** — the service must have a real IPv4 address (not empty, not a `169.254.x.x` self-assigned APIPA address).
4. **Active** if enabled + active link + real IP. Otherwise **Not Working**.

This only confirms local link + IP (L2/L3), not actual internet reachability — a service connected to a network with no internet access will still show as Working.
