import Foundation
import IOKit

/// GPU utilization / VRAM from IOAccelerator "PerformanceStatistics". Works for
/// Intel, AMD and Apple GPUs where exposed; fields are optional and degrade to nil.
public final class GPUReader {
    public init() {}

    public func read() -> [GPUInfo] {
        var gpus: [GPUInfo] = []
        var iterator: io_iterator_t = 0
        guard let matching = IOServiceMatching("IOAccelerator"),
              IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let gpu = parse(service) { gpus.append(gpu) }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return gpus
    }

    private func parse(_ service: io_service_t) -> GPUInfo? {
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else { return nil }

        var util: Double?
        var usedVRAM: UInt64?
        if let perf = dict["PerformanceStatistics"] as? [String: Any] {
            if let d = (perf["Device Utilization %"] as? NSNumber)?.doubleValue {
                util = min(1, d / 100.0)
            } else if let d = (perf["GPU Activity(%)"] as? NSNumber)?.doubleValue {
                util = min(1, d / 100.0)
            }
            usedVRAM = (perf["In use system memory"] as? NSNumber)?.uint64Value
                ?? (perf["vramUsedBytes"] as? NSNumber)?.uint64Value
        }
        var totalVRAM: UInt64?
        if let mb = (dict["VRAM,totalMB"] as? NSNumber)?.uint64Value { totalVRAM = mb * 1024 * 1024 }

        return GPUInfo(name: gpuName(service: service, props: dict),
                       utilization: util, usedVRAM: usedVRAM, totalVRAM: totalVRAM,
                       temperature: nil, fanSpeedRPM: nil)
    }

    private func gpuName(service: io_service_t, props: [String: Any]) -> String {
        if let n = modelString(props) { return n }
        var parent: io_registry_entry_t = 0
        if IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent) == KERN_SUCCESS, parent != 0 {
            defer { IOObjectRelease(parent) }
            var pprops: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(parent, &pprops, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let pdict = pprops?.takeRetainedValue() as? [String: Any], let n = modelString(pdict) {
                return n
            }
        }
        return "GPU"
    }

    private func modelString(_ dict: [String: Any]) -> String? {
        if let data = dict["model"] as? Data,
           let s = String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0 ")),
           !s.isEmpty {
            return s
        }
        if let s = dict["model"] as? String, !s.isEmpty { return s }
        return nil
    }
}
