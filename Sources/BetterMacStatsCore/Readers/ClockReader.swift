import Foundation

/// A single configured world-clock entry.
public struct ClockZone: Codable, Equatable, Identifiable {
    public var id: UUID
    public var label: String
    public var timeZoneID: String
    public var use24Hour: Bool
    public var showSeconds: Bool

    public init(id: UUID = UUID(), label: String, timeZoneID: String, use24Hour: Bool = true, showSeconds: Bool = false) {
        self.id = id
        self.label = label
        self.timeZoneID = timeZoneID
        self.use24Hour = use24Hour
        self.showSeconds = showSeconds
    }

    /// Default world clock starting with the user's current zone.
    public static var defaults: [ClockZone] {
        [ClockZone(label: "Local", timeZoneID: TimeZone.current.identifier)]
    }
}

public struct ClockReading: Equatable, Identifiable {
    public var id: UUID
    public var label: String
    public var time: String
    public var date: String
    public var timeZoneID: String
    public var offsetDescription: String

    public init(id: UUID, label: String, time: String, date: String, timeZoneID: String, offsetDescription: String) {
        self.id = id
        self.label = label
        self.time = time
        self.date = date
        self.timeZoneID = timeZoneID
        self.offsetDescription = offsetDescription
    }
}

/// Formats configured world clocks. Pure Foundation; works on every Mac.
public final class ClockReader {
    private var formatterCache: [String: DateFormatter] = [:]

    public init() {}

    public func read(zones: [ClockZone], at date: Date = Date()) -> [ClockReading] {
        zones.map { reading(for: $0, at: date) }
    }

    public func reading(for zone: ClockZone, at date: Date = Date()) -> ClockReading {
        let tz = TimeZone(identifier: zone.timeZoneID) ?? .current
        let timeFmt = formatter(timeZone: tz, pattern: timePattern(for: zone))
        let dateFmt = formatter(timeZone: tz, pattern: "EEE, d MMM")
        return ClockReading(
            id: zone.id,
            label: zone.label,
            time: timeFmt.string(from: date),
            date: dateFmt.string(from: date),
            timeZoneID: zone.timeZoneID,
            offsetDescription: offsetString(for: tz, at: date)
        )
    }

    private func timePattern(for zone: ClockZone) -> String {
        let base = zone.use24Hour ? "HH:mm" : "h:mm"
        let withSeconds = zone.showSeconds ? base.replacingOccurrences(of: "mm", with: "mm:ss") : base
        return zone.use24Hour ? withSeconds : withSeconds + " a"
    }

    private func formatter(timeZone: TimeZone, pattern: String) -> DateFormatter {
        let key = timeZone.identifier + "|" + pattern
        if let cached = formatterCache[key] { return cached }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = pattern
        formatterCache[key] = f
        return f
    }

    private func offsetString(for tz: TimeZone, at date: Date) -> String {
        let seconds = tz.secondsFromGMT(for: date)
        let sign = seconds >= 0 ? "+" : "-"
        let abs = Swift.abs(seconds)
        let h = abs / 3600
        let m = (abs % 3600) / 60
        return m == 0 ? "GMT\(sign)\(h)" : String(format: "GMT%@%d:%02d", sign, h, m)
    }
}
