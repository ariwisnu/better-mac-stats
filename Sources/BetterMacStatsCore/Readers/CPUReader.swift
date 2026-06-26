import Foundation
import Darwin

public struct CPUStaticInfo: Equatable {
    public var brand: String
    public var physicalCores: Int
    public var logicalCores: Int

    public init(brand: String, physicalCores: Int, logicalCores: Int) {
        self.brand = brand
        self.physicalCores = physicalCores
        self.logicalCores = logicalCores
    }
}

/// Per-core and aggregate CPU load via `host_processor_info`. Tick counters are
/// monotonic, so usage is the delta between two successive reads.
public final class CPUReader {
    private var previous: [UInt32]?

    public init() {}

    public func staticInfo() -> CPUStaticInfo {
        let brand = Sysctl.string("machdep.cpu.brand_string")
            ?? Sysctl.string("hw.model")
            ?? "Unknown CPU"
        let physical = Int(Sysctl.int32("hw.physicalcpu") ?? Int32(ProcessInfo.processInfo.processorCount))
        let logical = Int(Sysctl.int32("hw.logicalcpu") ?? Int32(ProcessInfo.processInfo.processorCount))
        return CPUStaticInfo(brand: brand, physicalCores: physical, logicalCores: logical)
    }

    public func read() -> CPULoad {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount)
        guard kr == KERN_SUCCESS, let info = info else { return .zero }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(UInt(bitPattern: OpaquePointer(info))),
                          vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }

        let states = Int(CPU_STATE_MAX)
        let n = Int(cpuCount)
        let buffer = UnsafeBufferPointer(start: info, count: Int(infoCount))
        var current = [UInt32](repeating: 0, count: n * states)
        for i in 0 ..< (n * states) {
            current[i] = UInt32(bitPattern: buffer[i])
        }

        var perCore = [Double](repeating: 0, count: n)
        var sumUser = 0.0, sumSys = 0.0, sumIdle = 0.0, sumNice = 0.0

        if let prev = previous, prev.count == current.count {
            for c in 0 ..< n {
                let base = c * states
                let user = Double(current[base + Int(CPU_STATE_USER)] &- prev[base + Int(CPU_STATE_USER)])
                let sys = Double(current[base + Int(CPU_STATE_SYSTEM)] &- prev[base + Int(CPU_STATE_SYSTEM)])
                let idle = Double(current[base + Int(CPU_STATE_IDLE)] &- prev[base + Int(CPU_STATE_IDLE)])
                let nice = Double(current[base + Int(CPU_STATE_NICE)] &- prev[base + Int(CPU_STATE_NICE)])
                let totalTicks = user + sys + idle + nice
                perCore[c] = totalTicks > 0 ? (user + sys + nice) / totalTicks : 0
                sumUser += user; sumSys += sys; sumIdle += idle; sumNice += nice
            }
        }
        previous = current

        let total = sumUser + sumSys + sumIdle + sumNice
        guard total > 0 else {
            return CPULoad(system: 0, user: 0, idle: 1, nice: 0, perCore: perCore)
        }
        return CPULoad(system: sumSys / total, user: sumUser / total,
                       idle: sumIdle / total, nice: sumNice / total, perCore: perCore)
    }
}
