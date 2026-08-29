# ResourceMonitor

A lightweight macOS menu bar app that shows live **CPU**, **memory**, and **network** usage — with an optional floating desktop panel and a WidgetKit extension.

![macOS](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![Xcode](https://img.shields.io/badge/Xcode-15%2B-lightgrey)

## Features

- **Menu bar monitor** — glanceable CPU and memory with SF Symbol icons
- **Optional menu bar values** — toggle “Show CPU & Memory in menu bar” for live percentages next to the icons
- **Desktop Panel** — dark, borderless floating card with CPU, memory, and network rates
- **WidgetKit extension** — system desktop widget (updates are throttled by macOS; the menu bar / panel stay live)
- Samples about every **3 seconds** so the UI stays calm

## Requirements

- macOS 14 or later (developed on newer releases as well)
- Xcode 15+ (Xcode 27 if you’re on macOS 27)
- Apple ID for signing

## Project layout

```
ResourceMonitor/
├── ResourceMonitor/          # Menu bar app + desktop panel
├── ResourceMonitorWidget/    # WidgetKit extension
├── Shared/                   # Metrics models + system sampling
└── ResourceMonitor.xcodeproj
```

| Piece | Role |
| --- | --- |
| `SystemMetricsSampler` | Reads CPU, memory, and network via Darwin APIs |
| `MetricsSamplerService` | Timer-driven sampling for the running app |
| `MetricsStore` | Optional App Group sharing for the widget |
| `DesktopPanelView` | Floating dark panel UI |
| `MenuBarMetricsImage` | Fixed-width menu bar icon + percent rendering |

## Notes on the widget

WidgetKit does **not** refresh as often as an in-process menu bar app. Keep ResourceMonitor running for live values; treat the system widget as a best-effort glance.

If the menu bar status says **widget share unavailable**, App Group writes aren’t succeeding yet — the menu bar and desktop panel still work locally.

## Privacy

All metrics are read locally from the system. Nothing is sent over the network.

## License

Add a license of your choice before publishing widely (MIT is a common default for small tools like this).
