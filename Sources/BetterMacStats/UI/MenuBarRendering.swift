import AppKit
import BetterMacStatsCore

/// What a status item should display this tick.
struct MenuBarContent {
    var title: String
    var color: NSColor?
    var symbol: String?
}

enum MenuBarRenderer {
    static func content(for kind: ModuleKind, engine: StatsEngine, settings: AppSettings) -> MenuBarContent {
        let symbol = settings.showMenuBarIcons ? kind.symbol : nil
        func loadColor(_ f: Double) -> NSColor? { settings.colorCoded ? NSColor.load(f) : nil }

        switch kind {
        case .cpu:
            let v = engine.cpu.total
            return MenuBarContent(title: Formatting.percent(v), color: loadColor(v), symbol: symbol)

        case .gpu:
            let u = engine.gpus.first?.utilization
            return MenuBarContent(title: u.map { Formatting.percent($0) } ?? "—",
                                  color: u.flatMap(loadColor), symbol: symbol)

        case .memory:
            let v = engine.memory.usedFraction
            return MenuBarContent(title: Formatting.percent(v), color: loadColor(v), symbol: symbol)

        case .disk:
            let v = engine.disk.primary?.usedFraction ?? 0
            return MenuBarContent(title: Formatting.percent(v), color: loadColor(v), symbol: symbol)

        case .network:
            let n = engine.network
            return MenuBarContent(title: "↓\(shortRate(n.downloadBytesPerSec)) ↑\(shortRate(n.uploadBytesPerSec))",
                                  color: nil, symbol: symbol)

        case .battery:
            let b = engine.battery
            if !b.isPresent { return MenuBarContent(title: "AC", color: nil, symbol: symbol) }
            let bolt = b.isCharging ? "⚡︎" : ""
            return MenuBarContent(title: "\(b.percentage)%\(bolt)",
                                  color: settings.colorCoded ? NSColor.load(1 - Double(b.percentage) / 100) : nil,
                                  symbol: settings.showMenuBarIcons ? batterySymbol(b) : nil)

        case .sensors:
            let t = engine.cpuTemperature ?? engine.hottestTemperature
            return MenuBarContent(title: t.map { shortTemp($0, settings) } ?? "—",
                                  color: t.flatMap { settings.colorCoded ? NSColor.load(($0 - 30) / 65) : nil },
                                  symbol: symbol)

        case .bluetooth:
            let c = engine.connectedBluetoothCount
            return MenuBarContent(title: c > 0 ? "\(c)" : "", color: nil, symbol: kind.symbol)

        case .clock:
            return MenuBarContent(title: engine.clocks.first?.time ?? "--:--", color: nil, symbol: nil)
        }
    }

    private static func shortRate(_ bytesPerSec: Double) -> String {
        let v = max(0, bytesPerSec)
        if v < 1000 { return "0K" }
        let k = v / 1000
        if k < 1000 { return "\(Int(k))K" }
        let m = k / 1000
        return m < 100 ? String(format: "%.1fM", m) : "\(Int(m))M"
    }

    private static func shortTemp(_ celsius: Double, _ settings: AppSettings) -> String {
        let v = settings.useFahrenheit ? celsius * 9 / 5 + 32 : celsius
        return "\(Int(v.rounded()))°"
    }

    private static func batterySymbol(_ b: BatteryInfo) -> String {
        if b.isCharging { return "battery.100.bolt" }
        switch b.percentage {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }
}

extension NSColor {
    /// Green (idle) → red (saturated) ramp matching the SwiftUI `Palette`.
    static func load(_ fraction: Double) -> NSColor {
        let x = min(1, max(0, fraction.isFinite ? fraction : 0))
        return NSColor(hue: CGFloat((1 - x) * 0.33), saturation: 0.85, brightness: 0.9, alpha: 1)
    }
}
