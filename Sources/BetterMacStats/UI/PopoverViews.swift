import SwiftUI
import BetterMacStatsCore

// MARK: - Shared formatting helpers

func formatTemp(_ celsius: Double?, _ settings: AppSettings) -> String {
    guard let celsius else { return "—" }
    return Formatting.temperature(celsius, fahrenheit: settings.useFahrenheit)
}

func formatRate(_ bytesPerSec: Double, _ settings: AppSettings) -> String {
    guard settings.networkInBits else { return Formatting.bytesPerSecond(bytesPerSec) }
    let bits = max(0, bytesPerSec) * 8
    let units = ["bps", "Kbps", "Mbps", "Gbps"]
    var v = bits, i = 0
    while v >= 1000 && i < units.count - 1 { v /= 1000; i += 1 }
    return String(format: i == 0 ? "%.0f %@" : "%.1f %@", v, units[i])
}

// MARK: - Dispatcher

struct ModulePopover: View {
    let kind: ModuleKind
    @ObservedObject var engine: StatsEngine
    @ObservedObject var settings: AppSettings
    var onOpenSettings: () -> Void

    var body: some View {
        switch kind {
        case .cpu: CPUPopover(engine: engine, settings: settings, onOpenSettings: onOpenSettings)
        case .gpu: GPUPopover(engine: engine, settings: settings, onOpenSettings: onOpenSettings)
        case .memory: MemoryPopover(engine: engine, settings: settings, onOpenSettings: onOpenSettings)
        case .disk: DiskPopover(engine: engine, settings: settings, onOpenSettings: onOpenSettings)
        case .network: NetworkPopover(engine: engine, settings: settings, onOpenSettings: onOpenSettings)
        case .battery: BatteryPopover(engine: engine, settings: settings, onOpenSettings: onOpenSettings)
        case .sensors: SensorsPopover(engine: engine, settings: settings, onOpenSettings: onOpenSettings)
        case .bluetooth: BluetoothPopover(engine: engine, settings: settings, onOpenSettings: onOpenSettings)
        case .clock: ClockPopover(engine: engine, settings: settings, onOpenSettings: onOpenSettings)
        }
    }
}

// MARK: - CPU

struct CPUPopover: View {
    @ObservedObject var engine: StatsEngine
    @ObservedObject var settings: AppSettings
    var onOpenSettings: () -> Void

    var body: some View {
        let load = engine.cpu
        PopoverScaffold(title: "CPU", systemImage: "cpu", onOpenSettings: onOpenSettings) {
            HStack(spacing: 14) {
                RingGauge(fraction: load.total, color: Palette.load(load.total),
                          label: Formatting.percent(load.total), caption: "load")
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 5) {
                    StatRow("System", Formatting.percent(load.system))
                    StatRow("User", Formatting.percent(load.user))
                    if engine.cpuTemperature != nil {
                        StatRow("Temperature", formatTemp(engine.cpuTemperature, settings))
                    }
                    StatRow("Cores", "\(engine.cpuStatic.physicalCores)P / \(engine.cpuStatic.logicalCores)L")
                }
            }
            Sparkline(values: engine.cpuHistory, color: Palette.load(load.total), maxValue: 1)
                .frame(height: 40)
            if !load.perCore.isEmpty {
                Divider()
                SectionLabel(text: "Per-core")
                ForEach(Array(load.perCore.enumerated()), id: \.offset) { idx, value in
                    HStack(spacing: 6) {
                        Text("\(idx)").font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary).frame(width: 16, alignment: .trailing)
                        MiniBar(fraction: value, color: Palette.load(value))
                        Text(Formatting.percent(value)).font(.system(size: 10, design: .monospaced))
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
            Text(engine.cpuStatic.brand).font(.system(size: 10)).foregroundColor(.secondary)
        }
    }
}

// MARK: - GPU

struct GPUPopover: View {
    @ObservedObject var engine: StatsEngine
    @ObservedObject var settings: AppSettings
    var onOpenSettings: () -> Void

    var body: some View {
        PopoverScaffold(title: "GPU", systemImage: "cube.transparent", onOpenSettings: onOpenSettings) {
            if engine.gpus.isEmpty {
                EmptyState(text: "No GPU data available on this Mac.")
            } else {
                ForEach(engine.gpus) { gpu in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(gpu.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        if let util = gpu.utilization {
                            LabeledBar(label: "Utilization", detail: Formatting.percent(util),
                                       fraction: util, color: Palette.load(util))
                        }
                        if let used = gpu.usedVRAM {
                            let total = gpu.totalVRAM
                            StatRow("VRAM in use", Formatting.bytes(used)
                                + (total != nil ? " / \(Formatting.bytes(total!))" : ""))
                        }
                        if let t = gpu.temperature {
                            StatRow("Temperature", formatTemp(t, settings))
                        }
                    }
                    .padding(.bottom, 4)
                }
                Sparkline(values: engine.gpuHistory, color: .purple, maxValue: 1).frame(height: 36)
            }
        }
    }
}

// MARK: - Memory

struct MemoryPopover: View {
    @ObservedObject var engine: StatsEngine
    @ObservedObject var settings: AppSettings
    var onOpenSettings: () -> Void

    var body: some View {
        let m = engine.memory
        PopoverScaffold(title: "Memory", systemImage: "memorychip", onOpenSettings: onOpenSettings) {
            HStack(spacing: 14) {
                RingGauge(fraction: m.usedFraction, color: Palette.load(m.usedFraction),
                          label: Formatting.percent(m.usedFraction), caption: "used")
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 5) {
                    StatRow("Used", Formatting.bytes(m.used))
                    StatRow("Free", Formatting.bytes(m.free))
                    StatRow("Total", Formatting.bytes(m.total))
                }
            }
            Sparkline(values: engine.memHistory, color: Palette.load(m.usedFraction), maxValue: 1)
                .frame(height: 36)
            Divider()
            StatRow("App", Formatting.bytes(m.app))
            StatRow("Wired", Formatting.bytes(m.wired))
            StatRow("Compressed", Formatting.bytes(m.compressed))
            StatRow("Cached", Formatting.bytes(m.cached))
            if m.swapTotal > 0 {
                StatRow("Swap", "\(Formatting.bytes(m.swapUsed)) / \(Formatting.bytes(m.swapTotal))")
            }
        }
    }
}

// MARK: - Disk

struct DiskPopover: View {
    @ObservedObject var engine: StatsEngine
    @ObservedObject var settings: AppSettings
    var onOpenSettings: () -> Void

    var body: some View {
        let d = engine.disk
        PopoverScaffold(title: "Disk", systemImage: "internaldrive", onOpenSettings: onOpenSettings) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(Formatting.bytesPerSecond(d.readBytesPerSec), systemImage: "arrow.down")
                        .font(.system(size: 12, weight: .medium)).foregroundColor(.blue)
                    Sparkline(values: engine.diskReadHistory, color: .blue).frame(height: 24)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Label(Formatting.bytesPerSecond(d.writeBytesPerSec), systemImage: "arrow.up")
                        .font(.system(size: 12, weight: .medium)).foregroundColor(.orange)
                    Sparkline(values: engine.diskWriteHistory, color: .orange).frame(height: 24)
                }
            }
            Divider()
            SectionLabel(text: "Volumes")
            if d.volumes.isEmpty {
                EmptyState(text: "No volumes detected.")
            } else {
                ForEach(d.volumes) { vol in
                    LabeledBar(label: vol.name,
                               detail: "\(Formatting.bytes(vol.free, binary: false)) free",
                               fraction: vol.usedFraction, color: Palette.load(vol.usedFraction))
                }
            }
        }
    }
}

// MARK: - Network

struct NetworkPopover: View {
    @ObservedObject var engine: StatsEngine
    @ObservedObject var settings: AppSettings
    var onOpenSettings: () -> Void

    var body: some View {
        let n = engine.network
        PopoverScaffold(title: "Network", systemImage: "network", onOpenSettings: onOpenSettings) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(formatRate(n.downloadBytesPerSec, settings), systemImage: "arrow.down")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.green)
                    Sparkline(values: engine.netDownHistory, color: .green).frame(height: 28)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Label(formatRate(n.uploadBytesPerSec, settings), systemImage: "arrow.up")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.blue)
                    Sparkline(values: engine.netUpHistory, color: .blue).frame(height: 28)
                }
            }
            Divider()
            if let iface = n.interfaceName { StatRow("Interface", "\(iface)\(n.connectionType.map { " · \($0)" } ?? "")") }
            if let ip = n.localIP { StatRow("Local IP", ip) }
            StatRow("Total received", Formatting.bytes(n.totalDownloaded, binary: false))
            StatRow("Total sent", Formatting.bytes(n.totalUploaded, binary: false))
        }
    }
}

// MARK: - Shared

struct EmptyState: View {
    var text: String
    var body: some View {
        HStack {
            Image(systemName: "info.circle").foregroundColor(.secondary)
            Text(text).font(.system(size: 12)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}
