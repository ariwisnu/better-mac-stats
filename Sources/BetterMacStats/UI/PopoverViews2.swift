import SwiftUI
import BetterMacStatsCore

// MARK: - Battery

struct BatteryPopover: View {
    @ObservedObject var engine: StatsEngine
    @ObservedObject var settings: AppSettings
    var onOpenSettings: () -> Void

    var body: some View {
        let b = engine.battery
        PopoverScaffold(title: "Battery", systemImage: "battery.100", onOpenSettings: onOpenSettings) {
            if !b.isPresent {
                EmptyState(text: "No internal battery — this Mac runs on AC power.")
            } else {
                let frac = Double(b.percentage) / 100.0
                let color = b.isCharging ? Color.green : Palette.load(1 - frac)
                HStack(spacing: 14) {
                    RingGauge(fraction: frac, color: color,
                              label: "\(b.percentage)%", caption: b.isCharging ? "charging" : nil)
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 5) {
                        StatRow("Status", statusText(b))
                        if b.isCharging, let f = b.timeToFullMinutes {
                            StatRow("Time to full", Formatting.duration(minutes: f))
                        } else if let e = b.timeToEmptyMinutes {
                            StatRow("Time remaining", Formatting.duration(minutes: e))
                        }
                        if let t = b.temperature { StatRow("Temperature", formatTemp(t, settings)) }
                    }
                }
                Divider()
                if let h = b.healthPercent { StatRow("Health", "\(h)%", color: Palette.load(1 - Double(h) / 100)) }
                if let c = b.cycleCount { StatRow("Cycle count", "\(c)") }
                if let cond = b.conditionString { StatRow("Condition", cond) }
                if let mx = b.maxCapacity, let dz = b.designCapacity {
                    StatRow("Capacity", "\(mx) / \(dz) mAh")
                }
            }
        }
    }

    private func statusText(_ b: BatteryInfo) -> String {
        if b.isCharged { return "Charged" }
        if b.isCharging { return "Charging" }
        return b.onACPower ? "On AC (not charging)" : "On battery"
    }
}

// MARK: - Sensors

struct SensorsPopover: View {
    @ObservedObject var engine: StatsEngine
    @ObservedObject var settings: AppSettings
    var onOpenSettings: () -> Void

    var body: some View {
        PopoverScaffold(title: "Sensors", systemImage: "thermometer.medium", onOpenSettings: onOpenSettings) {
            if engine.sensors.isEmpty {
                EmptyState(text: "No sensor data is exposed on this Mac.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        group("Temperatures", engine.temperatureSensors)
                        group("Fans", engine.fanSensors)
                        group("Power", engine.powerSensors)
                    }
                }
                .frame(maxHeight: 320)
            }
        }
    }

    @ViewBuilder
    private func group(_ title: String, _ readings: [SensorReading]) -> some View {
        if !readings.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                SectionLabel(text: title)
                ForEach(readings) { s in
                    StatRow(s.name, value(s), color: color(s))
                }
            }
        }
    }

    private func value(_ s: SensorReading) -> String {
        switch s.kind {
        case .temperature: return formatTemp(s.value, settings)
        case .fan: return "\(Int(s.value)) RPM"
        case .power: return String(format: "%.1f W", s.value)
        default: return String(format: "%.1f %@", s.value, s.unit)
        }
    }

    private func color(_ s: SensorReading) -> Color? {
        guard s.kind == .temperature else { return nil }
        // 30°C → green, 95°C → red
        return Palette.load((s.value - 30) / 65)
    }
}

// MARK: - Bluetooth

struct BluetoothPopover: View {
    @ObservedObject var engine: StatsEngine
    @ObservedObject var settings: AppSettings
    var onOpenSettings: () -> Void

    var body: some View {
        PopoverScaffold(title: "Bluetooth", systemImage: "dot.radiowaves.right", onOpenSettings: onOpenSettings) {
            if engine.bluetooth.isEmpty {
                EmptyState(text: "No paired Bluetooth devices.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(engine.bluetooth.sorted { $0.isConnected && !$1.isConnected }) { dev in
                            HStack(spacing: 8) {
                                Circle().fill(dev.isConnected ? Color.green : Color.secondary.opacity(0.4))
                                    .frame(width: 7, height: 7)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(dev.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                    Text(dev.kind).font(.system(size: 10)).foregroundColor(.secondary)
                                }
                                Spacer()
                                if let pct = dev.batteryPercent {
                                    Text("\(pct)%").font(.system(size: 11))
                                } else if let rssi = dev.rssi, dev.isConnected {
                                    Text("\(rssi) dBm").font(.system(size: 10)).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
    }
}

// MARK: - Clock

struct ClockPopover: View {
    @ObservedObject var engine: StatsEngine
    @ObservedObject var settings: AppSettings
    var onOpenSettings: () -> Void

    var body: some View {
        PopoverScaffold(title: "Clock", systemImage: "clock", onOpenSettings: onOpenSettings) {
            if engine.clocks.isEmpty {
                EmptyState(text: "Add a time zone in Settings.")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(engine.clocks) { c in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(c.label).font(.system(size: 12, weight: .medium))
                                Text("\(c.date) · \(c.offsetDescription)")
                                    .font(.system(size: 10)).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(c.time).font(.system(size: 20, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }
}
