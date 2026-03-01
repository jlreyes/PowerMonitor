# PowerMonitor

A lightweight macOS menu bar app that monitors power draw vs charger input in real-time. Warns you when your system is drawing more power than your charger can supply.

![menu bar screenshot](https://github.com/user-attachments/assets/placeholder)

## Features

- **Event-driven** — uses `IOPSNotificationCreateRunLoopSource` for near-zero CPU usage when idle
- **Menu bar icon** — shows current wattage with warning indicator when draining while plugged in
- **Native notifications** — alerts you when battery is draining despite being plugged in (5-min cooldown)
- **Live power stats** — charger wattage, battery flow, estimated system draw, battery %, cycle count
- **No dependencies** — single Swift file, compiles with `swiftc`, no Xcode project needed

## Why?

If you use a low-wattage charger (e.g. 27W) with a high-performance laptop (e.g. MacBook Pro M2 Max), your system can easily draw more than the charger provides under load — draining your battery even while plugged in. This app makes that visible at a glance.

## Install

### Build from source

```bash
git clone https://github.com/jlreyes/PowerMonitor.git
cd PowerMonitor
make install
```

### Manual build

```bash
mkdir -p PowerMonitor.app/Contents/MacOS
swiftc -parse-as-library -framework Cocoa -framework IOKit -framework UserNotifications \
  -O -o PowerMonitor.app/Contents/MacOS/PowerMonitor PowerMonitor.swift
cp Info.plist PowerMonitor.app/Contents/Info.plist
open -a PowerMonitor.app
```

## Auto-start on login

```bash
make launchd-install
```

This installs a LaunchAgent that opens PowerMonitor when you log in. To remove:

```bash
make launchd-uninstall
```

## Menu bar states

| Icon | Meaning |
|---|---|
| ⚡ 12W | Plugged in, charging at 12W into battery |
| ▲ 5W | Plugged in, draining at 5W (charger can't keep up) |
| 63% | On battery |

## Requirements

- macOS 13+ (Ventura or later)
- Swift 5.9+

## License

MIT
