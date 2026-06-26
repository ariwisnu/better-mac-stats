import Foundation
import Darwin

/// Physical memory + swap via `host_statistics64` and `vm.swapusage`.
public final class MemoryReader {
    private let pageSize: UInt64
    private let total: UInt64

    public init() {
        var ps: vm_size_t = 0
        host_page_size(mach_host_self(), &ps)
        pageSize = ps > 0 ? UInt64(ps) : 4096
        total = Sysctl.uint64("hw.memsize") ?? 0
    }

    public func read() -> MemoryUsage {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)

        let kr = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return .zero }

        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let free = UInt64(stats.free_count) * pageSize
        let inactive = UInt64(stats.inactive_count) * pageSize
        let purgeable = UInt64(stats.purgeable_count) * pageSize

        // Approximation of Activity Monitor's "Memory Used".
        let used = active + wired + compressed
        let cached = inactive + purgeable

        var xsw = xsw_usage()
        var xlen = MemoryLayout<xsw_usage>.size
        sysctlbyname("vm.swapusage", &xsw, &xlen, nil, 0)

        let pressure = total > 0 ? min(1, Double(used) / Double(total)) : 0
        return MemoryUsage(total: total, used: used, app: active, wired: wired,
                           compressed: compressed, cached: cached, free: free,
                           swapUsed: xsw.xsu_used, swapTotal: xsw.xsu_total, pressure: pressure)
    }
}
