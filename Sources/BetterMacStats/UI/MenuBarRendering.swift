import AppKit
import BetterMacStatsCore

/// What a status item should display this tick.
struct MenuBarContent {
    var title: String
    var color: NSColor?
    var symbol: String?
    /// What VoiceOver reads after the module name; defaults to the title.
    var spoken: String?
}

enum MenuBarRenderer {
    static func content(for kind: ModuleKind, engine: StatsEngine, settings: AppSettings) -> MenuBarContent {
        let symbol = settings.showMenuBarIcons ? kind.symbol : nil
        func flag(_ severity: Severity) -> NSColor? { settings.colorCoded ? severity.menuBar : nil }

        switch kind {
        case .cpu:
            let v = engine.cpu.total
            return MenuBarContent(title: Formatting.percent(v), color: flag(.load(v)), symbol: symbol)

        case .gpu:
            let u = engine.gpus.first?.utilization
            return MenuBarContent(title: u.map { Formatting.percent($0) } ?? "—",
                                  color: u.flatMap { flag(.load($0)) }, symbol: symbol)

        case .memory:
            let m = engine.memory
            return MenuBarContent(title: Formatting.percent(m.usedFraction),
                                  color: flag(Severity(m.pressure)), symbol: symbol)

        case .disk:
            let v = engine.disk.primary?.usedFraction ?? 0
            return MenuBarContent(title: Formatting.percent(v), color: flag(.disk(v)), symbol: symbol)

        case .network:
            let n = engine.network
            let bits = settings.networkInBits
            let down = shortRate(n.downloadBytesPerSec, bits: bits)
            let up = shortRate(n.uploadBytesPerSec, bits: bits)
            return MenuBarContent(title: "↓\(down) ↑\(up)", color: nil, symbol: symbol,
                                  spoken: "download \(down), upload \(up)")

        case .battery:
            let b = engine.battery
            if !b.isPresent { return MenuBarContent(title: "AC", color: nil, symbol: symbol) }
            let bolt = b.isCharging ? "⚡︎" : ""
            return MenuBarContent(title: "\(b.percentage)%\(bolt)",
                                  color: b.isCharging ? nil : flag(.battery(b.percentage)),
                                  symbol: settings.showMenuBarIcons ? batterySymbol(b) : nil,
                                  spoken: "\(b.percentage)%\(b.isCharging ? ", charging" : "")")

        case .sensors:
            let t = engine.cpuTemperature ?? engine.hottestTemperature
            return MenuBarContent(title: t.map { shortTemp($0, settings) } ?? "—",
                                  color: t.flatMap { flag(.temperature($0)) }, symbol: symbol)

        case .bluetooth:
            let c = engine.connectedBluetoothCount
            return MenuBarContent(title: c > 0 ? "\(c)" : "", color: nil, symbol: kind.symbol,
                                  spoken: "\(c) connected")

        case .clock:
            return MenuBarContent(title: engine.clocks.first?.time ?? "--:--", color: nil, symbol: nil)
        }
    }

    /// Compact rate: "1.2MB" in bytes, "9.6Mb" in bits.
    static func shortRate(_ bytesPerSec: Double, bits: Bool) -> String {
        let v = max(0, bytesPerSec) * (bits ? 8 : 1)
        let unit = bits ? "b" : "B"
        if v < 1000 { return "0K" + unit }
        let k = v / 1000
        if k < 1000 { return "\(Int(k))K" + unit }
        let m = k / 1000
        return (m < 100 ? String(format: "%.1fM", m) : "\(Int(m))M") + unit
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
