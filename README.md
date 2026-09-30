<p align="center">
  <img src="docs/logo.png" width="128" alt="Network Toggle logo">
</p>

<h1 align="center">Network Toggle</h1>

<p align="center">
  A macOS app that lists network services (from <code>networksetup -listnetworkserviceorder</code>), shows their status, and lets you turn them on/off from the menu bar and a Control Center. This is especially handy if you often switch between a wired Ethernet connection, a Wi-Fi network, a Personal Hotspot connection or phone USB connection.
</p>

<p align="center">
  <img src="docs/preview.gif" width="640" alt="Network Toggle preview">
</p>

<!--
  Логотип: docs/logo.png (квадратный, например 512x512 — то же изображение, что и AppIcon, подойдёт).
  Превью: docs/preview.gif — GIF надёжнее всего рендерится и в GitHub, и в GitLab, и на npm/сторонних зеркалах.
  Если хочешь именно .mp4, GitHub умеет встраивать <video> только через файлы, загруженные
  прямо в веб-редакторе README (drag-and-drop в текстовое поле на github.com) — обычный файл
  из репозитория так не воспроизведётся, поэтому GIF — более портируемый вариант.
-->

## Status logic

Each service has one of four states — the single source of truth read by both the menu bar and the Control Center:

1. **Inactive** — disabled in Network settings.
2. **Connecting…** — just enabled; within a short grace period (8s) after `-setnetworkserviceenabled`, giving the interface time to get a link and an IP.
3. **Not Connected** — enabled, past the grace period, but `ifconfig` shows no active link or no real (non-APIPA) IP.
4. **Connected** — enabled, with an active link and a real IP.

This only confirms local link + IP (L2/L3), not actual internet reachability — a service connected to a network with no internet access will still show as Connected.

## Privileged helper

Reading a service's status needs no special privileges, but actually turning one on or off (`networksetup -setnetworkserviceenabled`) does — it requires root. Since the app itself runs unprivileged, it installs a small privileged helper (a `launchd` daemon registered via `SMAppService.daemon`) whose only job is to run that one command over XPC, after checking that the request came from a process signed with the same Team ID.

Because the helper runs as root, macOS requires the user to explicitly approve it in System Settings → General → Login Items & Extensions — the app cannot register it silently, this confirmation step can't be skipped. The app requests approval automatically on launch whenever it isn't granted yet; if the prompt is missed or dismissed, the same request can be repeated from the menu ("Install Helper…" / "Open Settings…"). Until approved, everything except toggling still works — the service list and their statuses are read without the helper.
