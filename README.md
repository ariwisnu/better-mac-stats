<div align="center">

# Better Mac Stats

### A lightweight, native macOS menu bar system monitor for CPU, GPU, memory, disk, network, battery, temperatures, fans & Bluetooth.

A free and open‑source **Activity Monitor**, **[Stats](https://github.com/exelban/stats)** and **iStat Menus** alternative for **Apple Silicon (M1/M2/M3/M4)** and **Intel** Macs.

[![Platform](https://img.shields.io/badge/platform-macOS%2012%2B-1f6feb?logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5%20%7C%206-fa7343?logo=swift&logoColor=white)](https://swift.org)
[![Apple Silicon + Intel](https://img.shields.io/badge/Apple%20Silicon%20%2B%20Intel-universal-000000?logo=apple)](#requirements)
[![License: MIT](https://img.shields.io/github/license/ariwisnu/better-mac-stats?color=brightgreen)](LICENSE)
[![Stars](https://img.shields.io/github/stars/ariwisnu/better-mac-stats?style=social)](https://github.com/ariwisnu/better-mac-stats/stargazers)

**English** · [Bahasa Indonesia](README.id.md)

</div>

> Keep an eye on your Mac without ever opening Activity Monitor. Every metric is a
> separate menu bar item that opens a clean, live popover. Turn modules on or off to
> save CPU and battery — pay only for what you actually want to watch.

```
┌──────────────────────────────  your menu bar  ──────────────────────────────┐
   …            cpu 23%   69%   ↓1.2M ↑40K   61°   100%⚡   14:05               
└──────────────────────────────────────────────────────────────────────────────┘
                     │
                     ▼  left-click any item
        ╭────────────────────────────╮
        │  CPU                    ⚙︎  │
        │   ◯ 23%   System  6%       │
        │           User    17%      │
        │           Temp    61°C     │
        │  ▁▂▃▅▇▅▃▂▁  (live history)  │
        │  Cores ▇▅▃▂ ▂▁▃▅ …         │
        ╰────────────────────────────╯
```

<div align="center">

<img src="docs/screenshots/menubar.png" alt="Better Mac Stats live in the macOS menu bar" width="440"><br>
<sub><em>Every metric, live in your menu bar.</em></sub>

<br><br>

<img src="docs/screenshots/popovers.gif" alt="Live popovers cycling through CPU, memory, network, GPU, disk, sensors, battery and clock" width="300">

</div>

## Table of contents

- [Features](#features)
- [Screenshots](#screenshots)
- [Why Better Mac Stats?](#why-better-mac-stats)
- [Requirements](#requirements)
- [Install & build](#install--build)
- [Usage](#usage)
- [Settings](#settings)
- [Architecture](#architecture)
- [Widget](#widget)
- [Roadmap](#roadmap)
- [FAQ](#faq)
- [Contributing](#contributing)
- [License](#license)

## Screenshots

> Left‑click any menu bar item to open its live popover. Real captures on Apple M3.

<table>
<tr>
<td align="center"><img src="docs/screenshots/cpu.png" width="240"><br><b>CPU</b><br><sub>per‑core load + history</sub></td>
<td align="center"><img src="docs/screenshots/gpu.png" width="240"><br><b>GPU</b><br><sub>utilization + VRAM</sub></td>
<td align="center"><img src="docs/screenshots/memory.png" width="240"><br><b>Memory</b><br><sub>pressure breakdown</sub></td>
</tr>
<tr>
<td align="center"><img src="docs/screenshots/disk.png" width="240"><br><b>Disk</b><br><sub>I/O + volumes</sub></td>
<td align="center"><img src="docs/screenshots/network.png" width="240"><br><b>Network</b><br><sub>throughput + IP</sub></td>
<td align="center"><img src="docs/screenshots/sensors.png" width="240"><br><b>Sensors</b><br><sub>temperatures</sub></td>
</tr>
<tr>
<td align="center"><img src="docs/screenshots/battery.png" width="240"><br><b>Battery</b><br><sub>health + cycle count</sub></td>
<td align="center"><img src="docs/screenshots/clock.png" width="240"><br><b>Clock</b><br><sub>multi‑timezone</sub></td>
<td></td>
</tr>
</table>

## Features

| Module | Menu bar shows | Popover detail |
|--------|----------------|----------------|
| 🧠 **CPU** | total load % | per-core bars, system/user split, temperature, live sparkline, chip name |
| 🎮 **GPU** | utilization % | utilization, VRAM in use, GPU name (Intel / AMD / Apple) |
| 🧩 **Memory** | used % | used/free/total, app·wired·compressed·cached, swap, sparkline |
| 💽 **Disk** | primary used % | read/write throughput + sparklines, per-volume capacity bars |
| 🌐 **Network** | ↓ / ↑ speed | up/down + sparklines, interface, Wi‑Fi/Ethernet, local IP, totals |
| 🔋 **Battery** | % (+ charge bolt) | status, time remaining, cycle count, health, condition, temperature |
| 🌡️ **Sensors** | hottest CPU temp | every SMC temperature, fan RPM and power sensor |
| 📶 **Bluetooth** | connected count | paired devices, connection state, signal strength |
| 🕒 **Clock** | current time | multiple world clocks with date and GMT offset |

- ⚡ **Lightweight** — the whole app is **under 1 MB** and idles around **0.4% CPU**.
- 🎛️ **Customizable** — choose which modules appear, reorder them, set the refresh
  rate (500 ms – 10 s), pick °C/°F, bytes vs bits, color‑coding and icons.
- 🚀 **Launch at login** — via `SMAppService` (macOS 13+) or a LaunchAgent (macOS 12).
- 🍏 **Truly native** — AppKit `NSStatusItem` + SwiftUI popovers. No Electron, no
  background webview, no telemetry.
- 🛡️ **Graceful on every Mac** — missing fans, a desktop without a battery, or an
  SMC that exposes nothing are shown as a friendly empty state, never a crash.

## Why Better Mac Stats?

|  | **Better Mac Stats** | Activity Monitor | iStat Menus |
|--|:--:|:--:|:--:|
| Price | **Free & open source** | Free | Paid |
| Lives in the menu bar | ✅ 9 modules | ❌ | ✅ |
| Per‑core CPU + temps + fans | ✅ | partial | ✅ |
| Apple Silicon **and** Intel | ✅ | ✅ | ✅ |
| App size | **< 1 MB** | — | ~30 MB |
| Open source / hackable | ✅ | ❌ | ❌ |

Inspired by the excellent [exelban/stats](https://github.com/exelban/stats); Better
Mac Stats focuses on a tiny, readable, dependency‑free codebase you can build and
extend in minutes.

## Requirements

- **macOS 12 Monterey or later** (built and verified on macOS 26, Apple M3).
- A Swift toolchain — either full **Xcode** or the **Command Line Tools**
  (`xcode-select --install`).
- Universal: runs on **Apple Silicon** and **Intel**.
- Zero third‑party dependencies.

## Install & build

```bash
git clone https://github.com/ariwisnu/better-mac-stats.git
cd better-mac-stats

Scripts/build.sh              # → dist/BetterMacStats.app (arm64)
UNIVERSAL=1 Scripts/build.sh  # universal arm64 + x86_64
open dist/BetterMacStats.app  # launch

Scripts/run.sh                # build (if needed) + launch
Scripts/test.sh               # run the unit tests
```

> **Why scripts instead of `swift build`?**
> The Command Line Tools bundled with Swift 6.3.2 ship a broken
> `libPackageDescription` that fails to link *any* SwiftPM manifest (even an empty
> one), and `xcodebuild` needs full Xcode. The scripts compile directly with
> `swiftc`. `Package.swift` is included and builds normally in a healthy Xcode.

## Usage

- **Left‑click** a menu bar item → live detail popover.
- **Right‑click** (or ⌃‑click) any item → menu with **Settings…**, **Launch at
  Login**, and **Quit**.
- Disable every module and a single ⚙︎ item remains, so the app stays reachable.

## Settings

| Tab | What you can change |
|-----|---------------------|
| **General** | Launch at login · refresh interval (500 ms – 10 s) |
| **Modules** | Enable/disable each module · drag to reorder the menu bar |
| **Appearance** | Menu bar icons · color‑coded values · °C/°F · bytes vs bits/s |
| **Clock** | Add/remove world clocks · 24‑hour and seconds per zone |

## Architecture

```
Sources/
  BetterMacStatsCore/   Pure data layer (no AppKit) — readers, models, formatting
    Readers/            CPU · Memory · Network · Disk · Battery · GPU · SMC · Bluetooth · Clock
    Models/  Util/
  BetterMacStats/       The app — AppKit menu bar, SwiftUI popovers, settings
Tests/                  Unit tests
Widget/                 Optional WidgetKit extension
Scripts/                build · run · test · typecheck
```

Everything uses public macOS APIs: `host_processor_info` / `host_statistics64`
(CPU & memory), `getifaddrs` (network), the IOKit registry (disk I/O, GPU,
battery), `IOPSCopyPowerSourcesInfo` (battery), **AppleSMC** (temperatures, fans,
power) and **IOBluetooth** (devices). The clean `Core` ↔ `App` split keeps the
data layer unit‑testable and reusable (including by the widget).

## Widget

`Widget/` contains an optional **WidgetKit** widget (small + medium) showing CPU,
memory and battery. Because a Widget Extension is a separate `.appex` bundle, it
needs full Xcode: add a *Widget Extension* target, include
`Widget/BetterMacStatsWidget.swift` + the `BetterMacStatsCore` sources, and use
`Widget/Info.plist`.

## Roadmap

- [x] CPU, GPU, memory, disk, network, battery, sensors, Bluetooth, clock modules
- [x] Per‑module popovers with live sparklines
- [x] Settings (modules, interval, appearance, world clocks)
- [x] Launch at login (macOS 12 + 13+)
- [x] WidgetKit source
- [ ] One‑click widget embedding (no Xcode)
- [ ] Temperature / battery threshold notifications
- [ ] Per‑module refresh intervals
- [ ] Notarized signed release & Homebrew cask

Contributions to any of these are very welcome. ⭐ **Star the repo** to follow along!

## FAQ

**Does it work on Apple Silicon?** Yes — M1, M2, M3 and M4. Temperatures are read
straight from the SMC. Intel Macs are supported too.

**Will it drain my battery?** No. It idles around 0.4% CPU, and disabled modules
are not polled at all. Increase the refresh interval to use even less.

**Does it phone home?** Never. No network calls, no analytics, no telemetry.

**Why is a metric missing?** Some Macs don't expose certain sensors (e.g. fanless
Macs, desktops without a battery). Those degrade to a friendly empty state.

## Contributing

Issues and pull requests are welcome. The codebase is small, documented and has no
dependencies — a great place to learn macOS system programming. Run `Scripts/test.sh`
before sending a PR.

## License

[MIT](LICENSE) © contributors. Inspired by [exelban/stats](https://github.com/exelban/stats).

<div align="center">

If Better Mac Stats is useful to you, please **⭐ star the repository** — it helps a lot!

[![Star History Chart](https://api.star-history.com/svg?repos=ariwisnu/better-mac-stats&type=Date)](https://star-history.com/#ariwisnu/better-mac-stats&Date)

<sub>macOS menu bar system monitor · Activity Monitor alternative · Stats alternative · iStat Menus alternative · CPU GPU memory disk network battery temperature fan Bluetooth monitor · Apple Silicon M1 M2 M3 M4 · Intel · Monterey Ventura Sonoma Sequoia</sub>

</div>
