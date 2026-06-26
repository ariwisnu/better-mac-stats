import WidgetKit
import SwiftUI
import BetterMacStatsCore

// Optional macOS widget. This file is built as a separate Widget Extension target
// in Xcode (see README → "Widget"). It reuses BetterMacStatsCore readers. Widget
// extensions are sandboxed, so CPU / memory / battery work but SMC sensors may not;
// those fields degrade gracefully.

struct StatsEntry: TimelineEntry {
    let date: Date
    let cpu: Double
    let memory: Double
    let memoryUsed: UInt64
    let memoryTotal: UInt64
    let battery: Int?
    let charging: Bool
}

struct StatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(date: Date(), cpu: 0.25, memory: 0.6, memoryUsed: 9_000_000_000,
                   memoryTotal: 16_000_000_000, battery: 80, charging: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
        let entry = makeEntry()
        let refresh = Calendar.current.date(byAdding: .minute, value: 5, to: entry.date) ?? entry.date
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func makeEntry() -> StatsEntry {
        let cpuReader = CPUReader()
        _ = cpuReader.read()
        usleep(200_000)
        let load = cpuReader.read()
        let mem = MemoryReader().read()
        let battery = BatteryReader().read()
        return StatsEntry(date: Date(), cpu: load.total, memory: mem.usedFraction,
                          memoryUsed: mem.used, memoryTotal: mem.total,
                          battery: battery.isPresent ? battery.percentage : nil,
                          charging: battery.isCharging)
    }
}

private struct WidgetRing: View {
    var fraction: Double
    var color: Color
    var label: String
    var caption: String

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(color.opacity(0.18), lineWidth: 7)
                Circle().trim(from: 0, to: min(1, max(0, fraction)))
                    .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(label).font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            Text(caption).font(.system(size: 10)).foregroundColor(.secondary)
        }
    }
}

struct BetterMacStatsWidgetEntryView: View {
    var entry: StatsEntry
    @Environment(\.widgetFamily) private var family

    private func color(_ f: Double) -> Color { Color(hue: (1 - min(1, max(0, f))) * 0.33, saturation: 0.85, brightness: 0.9) }

    var body: some View {
        switch family {
        case .systemSmall:
            WidgetRing(fraction: entry.cpu, color: color(entry.cpu),
                       label: Formatting.percent(entry.cpu), caption: "CPU")
                .padding()
        default:
            HStack(spacing: 18) {
                WidgetRing(fraction: entry.cpu, color: color(entry.cpu),
                           label: Formatting.percent(entry.cpu), caption: "CPU")
                WidgetRing(fraction: entry.memory, color: color(entry.memory),
                           label: Formatting.percent(entry.memory), caption: "Memory")
                if let battery = entry.battery {
                    WidgetRing(fraction: Double(battery) / 100,
                               color: entry.charging ? .green : color(1 - Double(battery) / 100),
                               label: "\(battery)%", caption: entry.charging ? "Charging" : "Battery")
                }
            }
            .padding()
        }
    }
}

@main
struct BetterMacStatsWidget: Widget {
    private let kind = "BetterMacStatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatsProvider()) { entry in
            BetterMacStatsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Better Mac Stats")
        .description("Live CPU, memory and battery at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
