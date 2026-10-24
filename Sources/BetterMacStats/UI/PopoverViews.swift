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
        let severity = Severity.load(load.total)
        PopoverScaffold(title: "CPU", systemImage: "cpu", onOpenSettings: onOpenSettings) {
            HStack(spacing: 14) {
                RingGauge(fraction: load.total, color: severity.fill,
                          label: Formatting.percent(load.total), caption: "load")
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 5) {
                    StatRow("System", Formatting.percent(load.system))
                    StatRow("User", Formatting.percent(load.user))
                    if engine.cpuTemperature != nil {
                        StatRow("Temperature", formatTemp(engine.cpuTemperature, settings))
                    }
                    StatRow("Cores", engine.cpuStatic.coresDescription)
                }
            }
            Sparkline(values: engine.cpuHistory, color: severity.fill, maxValue: 1)
                .frame(height: 40)
            if !load.perCore.isEmpty {
                Divider()
                SectionLabel(text: "Per-core")
                ForEach(Array(load.perCore.enumerated()), id: \.offset) { idx, value in
                    HStack(spacing: 6) {
                        Text(coreLabel(idx)).font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary).frame(width: 22, alignment: .trailing)
                        MiniBar(fraction: value, color: Severity.load(value).fill)
                        Text(Formatting.percent(value)).font(.system(size: 10, design: .monospaced))
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }
            Text(engine.cpuStatic.brand).font(.system(size: 10)).foregroundColor(.secondary)
        }
    }

    /// "P1"…"E4" on Apple Silicon (numbered within each core type), "0"… on Intel.
    private func coreLabel(_ index: Int) -> String {
        let types = engine.cpuStatic.coreTypes
        guard index < types.count else { return "\(index)" }
        return types[index] + "\(types[...index].filter { $0 == types[index] }.count)"
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
                                       fraction: util, color: Severity.load(util).fill)
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
        let severity = Severity(m.pressure)
        PopoverScaffold(title: "Memory", systemImage: "memorychip", onOpenSettings: onOpenSettings) {
            HStack(spacing: 14) {
                RingGauge(fraction: m.usedFraction, color: severity.fill,
                          label: Formatting.percent(m.usedFraction), caption: "used")
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 5) {
                    StatRow("Used", Formatting.bytes(m.used))
                    StatRow("Available", Formatting.bytes(m.available))
                    StatRow("Pressure", pressureText(m.pressure), color: severity.text)
                }
            }
            Sparkline(values: engine.memHistory, color: severity.fill, maxValue: 1)
                .frame(height: 36)
            Divider()
            StatRow("Total", Formatting.bytes(m.total))
            StatRow("App", Formatting.bytes(m.app))
            StatRow("Wired", Formatting.bytes(m.wired))
            StatRow("Compressed", Formatting.bytes(m.compressed))
            StatRow("Cached", Formatting.bytes(m.cached))
            if m.swapTotal > 0 {
                StatRow("Swap", "\(Formatting.bytes(m.swapUsed)) / \(Formatting.bytes(m.swapTotal))")
            }
        }
    }

    private func pressureText(_ p: MemoryPressure) -> String {
        switch p {
        case .normal: return "Normal"
        case .warning: return "Elevated"
        case .critical: return "Critical"
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
                    Sparkline(values: engine.diskReadHistory, color: .blue, minCeiling: 1_000_000).frame(height: 24)
                    PeakLabel(Formatting.bytesPerSecond(engine.diskReadHistory.max() ?? 0))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Label(Formatting.bytesPerSecond(d.writeBytesPerSec), systemImage: "arrow.up")
                        .font(.system(size: 12, weight: .medium)).foregroundColor(.orange)
                    Sparkline(values: engine.diskWriteHistory, color: .orange, minCeiling: 1_000_000).frame(height: 24)
                    PeakLabel(Formatting.bytesPerSecond(engine.diskWriteHistory.max() ?? 0))
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
                               fraction: vol.usedFraction, color: Severity.disk(vol.usedFraction).fill)
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
                    Sparkline(values: engine.netDownHistory, color: .green, minCeiling: 100_000).frame(height: 28)
                    PeakLabel(formatRate(engine.netDownHistory.max() ?? 0, settings))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Label(formatRate(n.uploadBytesPerSec, settings), systemImage: "arrow.up")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.blue)
                    Sparkline(values: engine.netUpHistory, color: .blue, minCeiling: 100_000).frame(height: 28)
                    PeakLabel(formatRate(engine.netUpHistory.max() ?? 0, settings))
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

/// Peak of the last minute, so a chart's height has a scale.
struct PeakLabel: View {
    var text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text("peak \(text)").font(.system(size: 9)).foregroundColor(.secondary)
    }
}

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
