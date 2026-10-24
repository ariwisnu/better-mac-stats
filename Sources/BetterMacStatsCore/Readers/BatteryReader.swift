import Foundation
import IOKit
import IOKit.ps

/// Battery state via IOKit power sources, enriched with cycle count / health /
/// temperature from the AppleSmartBattery registry entry. Desktops report `.absent`.
public final class BatteryReader {
    public init() {}

    public func read() -> BatteryInfo {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            return .absent
        }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                  (desc[kIOPSTypeKey as String] as? String) == kIOPSInternalBatteryType else { continue }

            let current = desc[kIOPSCurrentCapacityKey as String] as? Int ?? 0
            let maxCap = desc[kIOPSMaxCapacityKey as String] as? Int ?? 100
            let pct = maxCap > 0 ? Int((Double(current) / Double(maxCap) * 100).rounded()) : current
            let charging = desc[kIOPSIsChargingKey as String] as? Bool ?? false
            let charged = desc[kIOPSIsChargedKey as String] as? Bool ?? false
            let onAC = (desc[kIOPSPowerSourceStateKey as String] as? String) == kIOPSACPowerValue
            let tte = desc[kIOPSTimeToEmptyKey as String] as? Int ?? -1
            let ttf = desc[kIOPSTimeToFullChargeKey as String] as? Int ?? -1

            let info = BatteryInfo(
                isPresent: true,
                percentage: max(0, min(100, pct)),
                isCharging: charging,
                isCharged: charged,
                onACPower: onAC,
                timeToEmptyMinutes: tte > 0 ? tte : nil,
                timeToFullMinutes: ttf > 0 ? ttf : nil,
                cycleCount: nil, healthPercent: nil, conditionString: nil,
                temperature: nil, designCapacity: nil, maxCapacity: nil
            )
            return enrich(info)
        }
        return .absent
    }

    /// Pull extra detail from the battery registry. Missing on desktops — returns input unchanged.
    private func enrich(_ base: BatteryInfo) -> BatteryInfo {
        // Newer macOS spreads the values over AppleSmartBattery, its child
        // AppleSmartBatteryPack, and each one's nested "BatteryData" dictionary.
        let dicts = ["AppleSmartBattery", "AppleSmartBatteryPack"].flatMap { name -> [[String: Any]] in
            guard let props = Self.properties(of: name) else { return [] }
            return [props, props["BatteryData"] as? [String: Any] ?? [:]]
        }
        guard !dicts.isEmpty else { return base }
        func number(_ key: String) -> Int? {
            dicts.lazy.compactMap { ($0[key] as? NSNumber)?.intValue }.first
        }

        var info = base
        info.cycleCount = number("CycleCount")
        let design = number("DesignCapacity")
        // "MaxCapacity" is a percentage on Apple Silicon, mAh only on older Macs.
        let maxCap = number("AppleRawMaxCapacity") ?? number("FullChargeCapacity")
            ?? number("MaxCapacity").flatMap { $0 > 100 ? $0 : nil }
        info.designCapacity = design
        info.maxCapacity = maxCap
        if let d = design, d > 0, let m = maxCap {
            info.healthPercent = Int((Double(m) / Double(d) * 100).rounded())
        }
        if let centiC = number("Temperature") {
            info.temperature = Double(centiC) / 100.0
        }
        info.conditionString = dicts.lazy.compactMap { $0["BatteryHealthCondition"] as? String }.first
            ?? (info.healthPercent != nil ? "Normal" : nil)
        return info
    }

    private static func properties(of className: String) -> [String: Any]? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(className))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS else { return nil }
        return props?.takeRetainedValue() as? [String: Any]
    }
}
