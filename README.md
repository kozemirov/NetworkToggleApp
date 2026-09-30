<p align="center">
  <img src="docs/logo.png" width="128" alt="Network Toggle logo">
</p>

<h1 align="center">Network Toggle App for Mac</h1>

A macOS app that lists network services (from <code>networksetup -listnetworkserviceorder</code>), shows their status, and lets you turn them on/off from the menu bar and a Control Center. This is especially handy if you often switch between a wired Ethernet connection, a Wi-Fi network, a Personal Hotspot connection or phone USB connection.

## Usage
<p align="center">
  <img src="docs/preview.gif" alt="Network Toggle preview">
</p>

## Download
Get NetworkToggleApp on [Gumroad](https://pavelkozemirov.gumroad.com/l/bheyzx) for $0

## Requirements
macOS version >= 26.0

## App Details
### Status logic
Each service has one of four states — the single source of truth read by both the menu bar and the Control Center:
1. **Inactive** — disabled in Network settings.
2. **Connecting…** — just enabled; within a short grace period (8s) after `-setnetworkserviceenabled`, giving the interface time to get a link and an IP.
3. **Not Connected** — enabled, past the grace period, but `ifconfig` shows no active link or no real (non-APIPA) IP.
4. **Connected** — enabled, with an active link and a real IP.
This only confirms local link + IP (L2/L3), not actual internet reachability — a service connected to a network with no internet access will still show as Connected.

### Privileged helper
Reading a service's status needs no special privileges, but actually turning one on or off (`networksetup -setnetworkserviceenabled`) does — it requires root. Since the app itself runs unprivileged, it installs a small privileged helper (a `launchd` daemon registered via `SMAppService.daemon`) whose only job is to run that one command over XPC, after checking that the request came from a process signed with the same Team ID.

Because the helper runs as root, macOS requires the user to explicitly approve it in System Settings → General → Login Items & Extensions — the app cannot register it silently, this confirmation step can't be skipped. The app requests approval automatically on launch whenever it isn't granted yet; if the prompt is missed or dismissed, the same request can be repeated from the menu ("Install Helper…" / "Open Settings…"). Until approved, everything except toggling still works — the service list and their statuses are read without the helper.

## FAQ
**What does the app actually do with elevated privileges — can it access anything else on my Mac?**

No. It only runs macOS's built-in `networksetup -setnetworkserviceenabled` command — nothing else. No file access, no network access, no other commands. Source is public on GitHub

## License
[PolyForm Noncommercial](https://github.com/kozemirov/NetworkToggleApp/blob/main/LICENSE)
