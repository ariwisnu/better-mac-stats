import Foundation

/// Pure, dependency-free formatting helpers shared by every module and the UI.
/// Kept deterministic so they can be unit-tested without touching hardware.
public enum Formatting {

    /// Human readable byte count. RAM-style modules pass `binary: true` (1024),
    /// disk/network pass `binary: false` (1000) to match Finder.
    public static func bytes(_ value: UInt64, binary: Bool = true, decimals: Int = 1) -> String {
        let unit: Double = binary ? 1024 : 1000
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        if value < UInt64(unit) { return "\(value) B" }
        var v = Double(value)
        var i = 0
        while v >= unit && i < units.count - 1 {
            v /= unit
            i += 1
        }
        return String(format: "%.\(decimals)f %@", v, units[i])
    }

    /// Byte rate, e.g. `1.2 MB/s`. Negative inputs are clamped to zero.
    public static func bytesPerSecond(_ value: Double, binary: Bool = false, decimals: Int = 1) -> String {
        let clamped = value < 0 ? 0 : value
        return bytes(UInt64(clamped.rounded()), binary: binary, decimals: decimals) + "/s"
    }

    /// Fraction in 0...1 rendered as a percentage. `percent(0.234) == "23%"`.
    public static func percent(_ fraction: Double, decimals: Int = 0) -> String {
        let clamped = fraction.isFinite ? max(0, fraction) : 0
        return String(format: "%.\(decimals)f%%", clamped * 100)
    }

    /// Temperature with unit suffix. Converts from Celsius when `fahrenheit` is set.
    public static func temperature(_ celsius: Double, fahrenheit: Bool = false, decimals: Int = 0) -> String {
        let v = fahrenheit ? celsius * 9 / 5 + 32 : celsius
        return String(format: "%.\(decimals)f°%@", v, fahrenheit ? "F" : "C")
    }

    /// Compact duration from minutes, e.g. `duration(133) == "2h 13m"`.
    public static func duration(minutes: Int) -> String {
        if minutes <= 0 { return "—" }
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    /// Frequency in Hz rendered as MHz/GHz.
    public static func frequency(hz: Double) -> String {
        if hz >= 1_000_000_000 { return String(format: "%.2f GHz", hz / 1_000_000_000) }
        if hz >= 1_000_000 { return String(format: "%.0f MHz", hz / 1_000_000) }
        return String(format: "%.0f Hz", hz)
    }
}
