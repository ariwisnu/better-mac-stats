import XCTest
@testable import BetterMacStatsCore

final class FormattingTests: XCTestCase {
    func testBytesBinary() {
        XCTAssertEqual(Formatting.bytes(512), "512 B")
        XCTAssertEqual(Formatting.bytes(1024), "1.0 KB")
        XCTAssertEqual(Formatting.bytes(1536), "1.5 KB")
        XCTAssertEqual(Formatting.bytes(1024 * 1024, decimals: 0), "1 MB")
    }

    func testBytesDecimal() {
        XCTAssertEqual(Formatting.bytes(1000, binary: false), "1.0 KB")
    }

    func testBytesPerSecond() {
        XCTAssertEqual(Formatting.bytesPerSecond(1_500_000, decimals: 1), "1.5 MB/s")
        XCTAssertEqual(Formatting.bytesPerSecond(-10), "0 B/s")
    }

    func testPercent() {
        XCTAssertEqual(Formatting.percent(0.234), "23%")
        XCTAssertEqual(Formatting.percent(1.0), "100%")
        XCTAssertEqual(Formatting.percent(-5), "0%")
        XCTAssertEqual(Formatting.percent(Double.nan), "0%")
    }

    func testDuration() {
        XCTAssertEqual(Formatting.duration(minutes: 133), "2h 13m")
        XCTAssertEqual(Formatting.duration(minutes: 45), "45m")
        XCTAssertEqual(Formatting.duration(minutes: 0), "—")
    }

    func testTemperature() {
        XCTAssertEqual(Formatting.temperature(20), "20°C")
        XCTAssertEqual(Formatting.temperature(0, fahrenheit: true), "32°F")
    }
}

final class RingBufferTests: XCTestCase {
    func testEvictsOldest() {
        var rb = RingBuffer<Int>(capacity: 3)
        rb.push(1); rb.push(2); rb.push(3); rb.push(4)
        XCTAssertEqual(rb.values, [2, 3, 4])
        XCTAssertEqual(rb.last, 4)
        XCTAssertEqual(rb.count, 3)
    }

    func testClear() {
        var rb = RingBuffer<Double>(capacity: 2)
        rb.push(1.0)
        rb.clear()
        XCTAssertTrue(rb.isEmpty)
    }
}

final class ClockReaderTests: XCTestCase {
    func testUTCDeterministic() {
        let reader = ClockReader()
        let zone = ClockZone(label: "UTC", timeZoneID: "UTC", use24Hour: true, showSeconds: false)
        let r = reader.reading(for: zone, at: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(r.time, "00:00")
        XCTAssertEqual(r.offsetDescription, "GMT+0")
        XCTAssertEqual(r.label, "UTC")
    }

    func testSecondsAndOffset() {
        let reader = ClockReader()
        // Tokyo is GMT+9, no DST.
        let zone = ClockZone(label: "Tokyo", timeZoneID: "Asia/Tokyo", use24Hour: true, showSeconds: true)
        let r = reader.reading(for: zone, at: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(r.time, "09:00:00")
        XCTAssertEqual(r.offsetDescription, "GMT+9")
    }
}

final class ModelTests: XCTestCase {
    func testCPUTotalClamped() {
        let load = CPULoad(system: 0.5, user: 0.7, idle: 0, nice: 0.1, perCore: [])
        XCTAssertEqual(load.total, 1.0) // clamped
    }

    func testMemoryFraction() {
        let m = MemoryUsage(total: 100, used: 25, app: 10, wired: 10, compressed: 5,
                            cached: 0, free: 75, swapUsed: 0, swapTotal: 0, pressure: 0.25)
        XCTAssertEqual(m.usedFraction, 0.25)
    }

    func testDiskPrimarySelection() {
        let root = DiskVolume(name: "Macintosh HD", path: "/", total: 100, free: 40, isRemovable: false)
        let ext = DiskVolume(name: "USB", path: "/Volumes/USB", total: 10, free: 1, isRemovable: true)
        let usage = DiskUsage(volumes: [ext, root], readBytesPerSec: 0, writeBytesPerSec: 0)
        XCTAssertEqual(usage.primary?.path, "/")
        XCTAssertEqual(root.used, 60)
    }
}
