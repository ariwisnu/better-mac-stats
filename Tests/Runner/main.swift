import Foundation

// Lightweight assertion harness. The installed Command Line Tools ship a broken
// libPackageDescription (SwiftPM cannot link any manifest), so we cannot use
// `swift test`. This runner is compiled directly with swiftc by Scripts/test.sh
// and exercises the same logic as Tests/BetterMacStatsCoreTests (kept for Xcode).

var failures = 0
var checks = 0

func eq<T: Equatable>(_ a: T, _ b: T, _ label: String, line: UInt = #line) {
    checks += 1
    if a != b {
        failures += 1
        print("  ✗ [\(line)] \(label): \(a) != \(b)")
    }
}

func ok(_ cond: Bool, _ label: String, line: UInt = #line) {
    checks += 1
    if !cond {
        failures += 1
        print("  ✗ [\(line)] \(label)")
    }
}

// MARK: Formatting

eq(Formatting.bytes(512), "512 B", "bytes <1KB")
eq(Formatting.bytes(1024), "1.0 KB", "bytes 1KB")
eq(Formatting.bytes(1536), "1.5 KB", "bytes 1.5KB")
eq(Formatting.bytes(1024 * 1024, decimals: 0), "1 MB", "bytes 1MB no-dec")
eq(Formatting.bytes(1000, binary: false), "1.0 KB", "bytes decimal")
eq(Formatting.bytesPerSecond(1_500_000, decimals: 1), "1.5 MB/s", "rate MB/s")
eq(Formatting.bytesPerSecond(-10), "0 B/s", "rate negative")
eq(Formatting.percent(0.234), "23%", "percent round")
eq(Formatting.percent(1.0), "100%", "percent 100")
eq(Formatting.percent(-5), "0%", "percent clamp low")
eq(Formatting.percent(Double.nan), "0%", "percent nan")
eq(Formatting.duration(minutes: 133), "2h 13m", "duration h+m")
eq(Formatting.duration(minutes: 45), "45m", "duration m")
eq(Formatting.duration(minutes: 0), "—", "duration zero")
eq(Formatting.temperature(20), "20°C", "temp C")
eq(Formatting.temperature(0, fahrenheit: true), "32°F", "temp F")

// MARK: RingBuffer

var rb = RingBuffer<Int>(capacity: 3)
rb.push(1); rb.push(2); rb.push(3); rb.push(4)
eq(rb.values, [2, 3, 4], "ring evict")
eq(rb.last ?? -1, 4, "ring last")
eq(rb.count, 3, "ring count")
rb.clear()
ok(rb.isEmpty, "ring clear")

// MARK: ClockReader

let clock = ClockReader()
let utc = clock.reading(for: ClockZone(label: "UTC", timeZoneID: "UTC", use24Hour: true, showSeconds: false),
                        at: Date(timeIntervalSince1970: 0))
eq(utc.time, "00:00", "clock UTC time")
eq(utc.offsetDescription, "GMT+0", "clock UTC offset")
let tokyo = clock.reading(for: ClockZone(label: "Tokyo", timeZoneID: "Asia/Tokyo", use24Hour: true, showSeconds: true),
                          at: Date(timeIntervalSince1970: 0))
eq(tokyo.time, "09:00:00", "clock Tokyo seconds")
eq(tokyo.offsetDescription, "GMT+9", "clock Tokyo offset")

// MARK: Models

let load = CPULoad(system: 0.5, user: 0.7, idle: 0, nice: 0.1, perCore: [])
eq(load.total, 1.0, "cpu total clamp")
let mem = MemoryUsage(total: 100, used: 25, app: 10, wired: 10, compressed: 5,
                      cached: 0, free: 75, swapUsed: 0, swapTotal: 0, pressure: 0.25)
eq(mem.usedFraction, 0.25, "mem fraction")
let root = DiskVolume(name: "Macintosh HD", path: "/", total: 100, free: 40, isRemovable: false)
let ext = DiskVolume(name: "USB", path: "/Volumes/USB", total: 10, free: 1, isRemovable: true)
let disk = DiskUsage(volumes: [ext, root], readBytesPerSec: 0, writeBytesPerSec: 0)
eq(disk.primary?.path ?? "?", "/", "disk primary is root")
eq(root.used, 60, "disk used")

// MARK: Result

print("")
if failures == 0 {
    print("✓ ALL \(checks) CHECKS PASSED")
} else {
    print("✗ \(failures)/\(checks) CHECKS FAILED")
    exit(1)
}
