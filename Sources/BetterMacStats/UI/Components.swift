import AppKit
import SwiftUI
import BetterMacStatsCore

/// Values are drawn in the normal text color; color only flags a problem, using
/// system colors so it stays readable on light and dark menu bars.
enum Severity {
    case normal, warning, critical

    init(_ value: Double, warning: Double, critical: Double) {
        self = value >= critical ? .critical : value >= warning ? .warning : .normal
    }

    init(_ pressure: MemoryPressure) {
        switch pressure {
        case .normal: self = .normal
        case .warning: self = .warning
        case .critical: self = .critical
        }
    }

    static func load(_ fraction: Double) -> Severity { Severity(fraction, warning: 0.7, critical: 0.9) }
    static func disk(_ fraction: Double) -> Severity { Severity(fraction, warning: 0.85, critical: 0.95) }
    static func temperature(_ celsius: Double) -> Severity { Severity(celsius, warning: 80, critical: 95) }
    /// 20% or less is a warning, 10% or less critical.
    static func battery(_ percent: Int) -> Severity { Severity(Double(100 - percent), warning: 80, critical: 90) }
    /// Below 80% capacity is when Apple recommends service.
    static func health(_ percent: Int) -> Severity { Severity(Double(100 - percent), warning: 21, critical: 41) }

    /// Text color; nil keeps the adaptive system label color.
    var text: Color? {
        switch self {
        case .normal: return nil
        case .warning: return .orange
        case .critical: return .red
        }
    }

    /// Bars, rings and charts.
    var fill: Color { text ?? .accentColor }

    var menuBar: NSColor? {
        switch self {
        case .normal: return nil
        case .warning: return .systemOrange
        case .critical: return .systemRed
        }
    }
}

/// A line + area sparkline drawn with Path so it runs on macOS 12 (no Swift Charts).
struct Sparkline: View {
    var values: [Double]
    var color: Color
    var fillOpacity: Double = 0.15
    /// Fixed scale ceiling; when nil the chart auto-scales to its own max.
    var maxValue: Double?
    /// Lowest auto-scale ceiling, so idle noise is not drawn as a full-height spike.
    var minCeiling: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if values.count >= 2 {
                    areaPath(in: geo.size).fill(color.opacity(fillOpacity))
                    linePath(in: geo.size).stroke(color, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                }
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        let ceiling = max(maxValue ?? max(values.max() ?? 1, minCeiling), 0.0001)
        let denom = CGFloat(max(values.count - 1, 1))
        return values.enumerated().map { i, v in
            CGPoint(x: size.width * CGFloat(i) / denom,
                    y: size.height * (1 - CGFloat(min(v / ceiling, 1))))
        }
    }

    private func linePath(in size: CGSize) -> Path {
        var path = Path()
        let pts = points(in: size)
        guard let first = pts.first else { return path }
        path.move(to: first)
        for pt in pts.dropFirst() { path.addLine(to: pt) }
        return path
    }

    private func areaPath(in size: CGSize) -> Path {
        var path = Path()
        let pts = points(in: size)
        guard let first = pts.first else { return path }
        path.move(to: CGPoint(x: 0, y: size.height))
        path.addLine(to: first)
        for pt in pts.dropFirst() { path.addLine(to: pt) }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.closeSubpath()
        return path
    }
}

/// Horizontal progress bar.
struct MiniBar: View {
    var fraction: Double
    var color: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule().fill(color)
                    .frame(width: max(0, min(1, fraction.isFinite ? fraction : 0)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

/// Circular gauge with a centered label.
struct RingGauge: View {
    var fraction: Double
    var color: Color
    var label: String
    var caption: String?

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.12), lineWidth: 8)
            Circle()
                .trim(from: 0, to: min(1, max(0, fraction.isFinite ? fraction : 0)))
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text(label).font(.system(size: 15, weight: .semibold, design: .rounded))
                if let caption { Text(caption).font(.system(size: 9)).foregroundColor(.secondary) }
            }
        }
    }
}

/// Label on the left, value on the right.
struct StatRow: View {
    var label: String
    var value: String
    var color: Color?

    init(_ label: String, _ value: String, color: Color? = nil) {
        self.label = label
        self.value = value
        self.color = color
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label).foregroundColor(.secondary)
            Spacer(minLength: 8)
            Text(value).fontWeight(.medium).foregroundColor(color ?? .primary)
                .multilineTextAlignment(.trailing)
        }
        .font(.system(size: 12))
    }
}

/// A labeled row with an inline progress bar (e.g. a disk volume).
struct LabeledBar: View {
    var label: String
    var detail: String
    var fraction: Double
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Spacer()
                Text(detail).font(.system(size: 11)).foregroundColor(.secondary)
            }
            MiniBar(fraction: fraction, color: color)
        }
    }
}

struct SectionLabel: View {
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Standard popover chrome: title row with a settings gear, content, and a footer.
struct PopoverScaffold<Content: View>: View {
    var title: String
    var systemImage: String
    var onOpenSettings: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: systemImage)
                Text(title).font(.headline)
            }
            content()
            Divider()
            HStack {
                Button("Settings…", action: onOpenSettings)
                    .buttonStyle(.link)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.link)
            }
            .font(.system(size: 11))
        }
        .padding(14)
        .frame(width: 280)
    }
}
