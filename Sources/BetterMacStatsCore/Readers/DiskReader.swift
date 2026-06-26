import Foundation
import IOKit

/// Volume capacities (FileManager) + aggregate read/write throughput
/// (IOBlockStorageDriver statistics).
public final class DiskReader {
    private var lastRead: UInt64 = 0
    private var lastWrite: UInt64 = 0
    private var lastTime: Date?

    public init() {}

    public func read(at now: Date = Date()) -> DiskUsage {
        let volumes = readVolumes()
        let (r, w) = readIOTotals()

        var rRate = 0.0, wRate = 0.0
        if let last = lastTime {
            let dt = now.timeIntervalSince(last)
            if dt > 0 {
                rRate = r >= lastRead ? Double(r - lastRead) / dt : 0
                wRate = w >= lastWrite ? Double(w - lastWrite) / dt : 0
            }
        }
        lastRead = r; lastWrite = w; lastTime = now
        return DiskUsage(volumes: volumes, readBytesPerSec: rRate, writeBytesPerSec: wRate)
    }

    private func readVolumes() -> [DiskVolume] {
        let keys: [URLResourceKey] = [
            .volumeNameKey, .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey,
            .volumeIsRemovableKey, .volumeIsBrowsableKey, .volumeIsLocalKey,
        ]
        guard let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys,
                                                               options: [.skipHiddenVolumes]) else { return [] }
        var result: [DiskVolume] = []
        for url in urls {
            guard let vals = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if vals.volumeIsBrowsable == false || vals.volumeIsLocal == false { continue }
            let total = UInt64(vals.volumeTotalCapacity ?? 0)
            if total == 0 { continue }
            let avail = vals.volumeAvailableCapacityForImportantUsage.map { UInt64(max(0, $0)) }
                ?? UInt64(vals.volumeAvailableCapacity ?? 0)
            result.append(DiskVolume(name: vals.volumeName ?? url.lastPathComponent,
                                     path: url.path, total: total, free: avail,
                                     isRemovable: vals.volumeIsRemovable ?? false))
        }
        // Boot volume first, then alphabetical.
        result.sort { a, b in
            if (a.path == "/") != (b.path == "/") { return a.path == "/" }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        return result
    }

    private func readIOTotals() -> (UInt64, UInt64) {
        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0
        var iterator: io_iterator_t = 0
        guard let matching = IOServiceMatching("IOBlockStorageDriver"),
              IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return (0, 0)
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any],
               let stats = dict["Statistics"] as? [String: Any] {
                if let r = (stats["Bytes (Read)"] as? NSNumber)?.uint64Value { totalRead &+= r }
                if let w = (stats["Bytes (Write)"] as? NSNumber)?.uint64Value { totalWrite &+= w }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return (totalRead, totalWrite)
    }
}
